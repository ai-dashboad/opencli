#!/usr/bin/env python3
"""Run the model-compatibility task against many models and score the results.

This is the batch form of the five-minute task in
`docs-site/docs/reference/checking-a-model.md`. It sets up the same fixture,
runs the same command with the same flags, and scores the same four columns,
so a row produced here is comparable with a row somebody sends in by hand.

    scripts/check-models.py --from-ollama
    scripts/check-models.py -m qwen3-coder:30b -m llama3.1:8b
    scripts/check-models.py --report            # rebuild the table, run nothing

What is and is not decided by machine
-------------------------------------
**Calls tools** is read from the event stream (`--json`), so it is certain: a
model either produced tool items or it did not.

The other three columns are read out of the model's prose, and prose does not
have a schema. They are scored against the report shape the skill asks for
(`Row 47 - INV-2231 - ...` / `Rule: "..."`), which most models that get the
task right will follow, and the evidence for each verdict is printed alongside
it so a human can confirm a table row in about twenty seconds rather than five
minutes. Anything the scorer is unsure about is marked `?`, never guessed.

Every run keeps its raw event stream and its final message under `--out`, so a
disputed verdict can always be settled by reading what the model actually said.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

# --------------------------------------------------------------------------
# The fixture
# --------------------------------------------------------------------------
# Byte-for-byte what the documentation tells a contributor to create. If these
# ever drift apart, rows produced by the script stop being comparable with rows
# sent in by hand, and the table quietly becomes two tables.

INVOICES_CSV = """row,invoice,customer,amount,po_number,date
1,INV-2201,Northwind,4200,,2026-08-03
2,INV-2202,Contoso,11800,,2026-08-05
3,INV-2203,Fabrikam,900,PO-771,2026-08-09
4,INV-2204,Northwind,15400,PO-772,2026-08-11
5,INV-2205,Contoso,,PO-773,2026-08-12
6,INV-2206,Tailspin,7300,,2026-13-02
"""

RULES_MD = """# Invoice rules

- Anything over 10,000 needs a PO number.
- Every invoice must have an amount.
- Dates are YYYY-MM-DD and must be real dates.
"""

PROMPT = "Use the spreadsheet-review skill on invoices.csv"

INVOICE_OF = {
    1: "INV-2201",
    2: "INV-2202",
    3: "INV-2203",
    4: "INV-2204",
    5: "INV-2205",
    6: "INV-2206",
}

BROKEN_ROWS = (2, 5, 6)
TOTAL_ROWS = 6

# Row 4 is over the limit *and* has a PO. It is in the fixture so that a model
# reporting every large amount does not score the same as one applying the
# rule. Rows 1 and 3 break nothing at all.
CLEAN_ROWS = (1, 3, 4)

# The rule each planted row breaks, and the words that identify it. Generous on
# purpose: this decides whether the finding was tied to its rule at all, which
# is a lower bar than the one the table sets, and the two are kept apart below.
RULE_WORDS = {
    2: r"\bP\.?O\.?\b|po[_ ]number|purchase[ -]order|10[,.]?000|ten thousand",
    5: r"\bamount\b|\bblank\b|\bempty\b|\bmissing\b|\bno value\b",
    6: r"\bdate\b|\bmonth\b|\b13\b|YYYY-MM-DD|\bcalendar\b",
}

# The table's column says the finding *quotes* the rule, so quoting has to be
# visible as something other than the model's own words: the rule's own wording
# carried across, or a `Rule:` label, or quotation marks around it. A model that
# identifies the right rule in its own phrasing has done most of the job, and is
# recorded as `paraphrased` rather than being failed silently.
RULE_QUOTES = {
    2: r"needs a PO number|anything over 10[,.]?000",
    5: r"must have an amount|every invoice must",
    6: r"must be real dates|YYYY-MM-DD",
}
QUOTE_MARKERS = re.compile(r"\bRule\b\s*[:\-]|[\"“”'']", re.I)

CITED_QUOTED, CITED_PARAPHRASED, CITED_NONE = "quoted", "paraphrased", "none"

# Item types in the event stream that mean the model reached for something
# rather than asking the human to paste the file in.
TOOL_ITEMS = {"command_execution", "file_change", "mcp_tool_call", "web_search"}


# --------------------------------------------------------------------------
# Reading the model's prose
# --------------------------------------------------------------------------

# "rows 2, 5 and 6" is one mention of three rows. Captured as a run and split
# afterwards, because a model listing them together is being clearer than one
# listing them apart, and should not be scored worse for it.
ROW_RUN = re.compile(r"\brows?\b[\s#:.]*((?:\d{1,3}\s*(?:,|and|&|/|、|;)?\s*){1,12})", re.I)

# "6 rows read" and "rows read: 6" are the same sentence written two ways.
COUNT_BEFORE = re.compile(r"\b(\d{1,3}|six|five|seven|four|all)\b[^.\n]{0,28}\brows?\b", re.I)
COUNT_AFTER = re.compile(r"\brows?\b[^.\n]{0,28}\b(\d{1,3}|six|five|seven|four|all)\b", re.I)

WORDY_NUMBERS = {"four": 4, "five": 5, "six": 6, "seven": 7}

# Everything under this heading is explicitly not a finding - the skill tells
# the model to park rows that look odd but break no rule here. Reporting row 4
# under it is correct behaviour, so it must not count as a false positive.
ASIDE = re.compile(r"worth a look|not a finding|no rule covers|for information", re.I)


def rows_mentioned(text: str) -> set[int]:
    """Which of the six rows this text refers to, by number or by invoice."""
    seen: set[int] = set()
    lowered = text.lower()

    for row, invoice in INVOICE_OF.items():
        if invoice.lower() in lowered:
            seen.add(row)

    for match in ROW_RUN.finditer(text):
        for number in re.findall(r"\d{1,3}", match.group(1)):
            value = int(number)
            if value in INVOICE_OF:
                seen.add(value)

    return seen


def split_findings(text: str) -> tuple[str, str]:
    """Separate the findings from the section that says it holds none."""
    match = ASIDE.search(text)
    if not match:
        return text, ""
    return text[: match.start()], text[match.start() :]


def window_around(text: str, row: int, reach: int = 340) -> str:
    """The text around the first reference to a row, for reading its rule from.

    A finding is two lines in the shape the skill asks for, so the rule that
    goes with a row is near it. Widening this much beyond a finding's own
    length starts picking up the next finding's rule instead.
    """
    positions = [text.lower().find(INVOICE_OF[row].lower())]
    for match in ROW_RUN.finditer(text):
        if str(row) in re.findall(r"\d{1,3}", match.group(1)):
            positions.append(match.start())
    hits = [at for at in positions if at >= 0]
    if not hits:
        return ""
    at = min(hits)
    return text[max(0, at - 80) : at + reach]


def count_claimed(text: str) -> int | None:
    """The number of rows the model says it read, if it says."""
    for pattern in (COUNT_BEFORE, COUNT_AFTER):
        for match in pattern.finditer(text):
            token = match.group(1).lower()
            if token in WORDY_NUMBERS:
                return WORDY_NUMBERS[token]
            if token == "all":
                continue
            if token.isdigit():
                value = int(token)
                # Row numbers and rule counts live in the same sentences; only
                # a plausible file length is a coverage claim.
                if 1 <= value <= 50:
                    return value
    return None


def count_sentence(text: str) -> str:
    """The sentence the count was taken from, so a human can check it."""
    for pattern in (COUNT_BEFORE, COUNT_AFTER):
        match = pattern.search(text)
        if match:
            start = text.rfind("\n", 0, match.start()) + 1
            end = text.find("\n", match.end())
            return text[start : end if end != -1 else len(text)].strip()
    return ""


# --------------------------------------------------------------------------
# Results
# --------------------------------------------------------------------------


@dataclass
class Result:
    model: str
    status: str = "ok"  # ok | failed | timeout | missing-binary
    error: str = ""
    seconds: float = 0.0

    calls_tools: bool = False
    tool_calls: int = 0
    edited_fixture: bool = False

    found: list[int] = field(default_factory=list)
    false_positives: list[int] = field(default_factory=list)
    cited: dict[str, str] = field(default_factory=dict)
    counted: int | None = None
    count_line: str = ""

    input_tokens: int = 0
    output_tokens: int = 0

    @property
    def ran(self) -> bool:
        return self.status == "ok"

    @property
    def found_all(self) -> bool:
        return sorted(self.found) == list(BROKEN_ROWS) and not self.false_positives

    @property
    def cited_all(self) -> bool:
        """Every planted row found, and every one of them quoting its rule."""
        return self.found_all and all(
            value == CITED_QUOTED for value in self.cited.values()
        )

    @property
    def cited_loosely(self) -> bool:
        """Every finding tied to the right rule, in whosever words."""
        return bool(self.cited) and all(
            value != CITED_NONE for value in self.cited.values()
        )

    @property
    def counted_right(self) -> bool:
        return self.counted == TOTAL_ROWS

    def to_dict(self) -> dict:
        data = {key: getattr(self, key) for key in self.__dataclass_fields__}
        data["found_all"] = self.found_all
        data["cited_all"] = self.cited_all
        data["counted_right"] = self.counted_right
        return data


def score(result: Result, events: list[dict], message: str) -> Result:
    """Turn one run into four verdicts."""
    for event in events:
        kind = event.get("type")

        if kind == "item.completed":
            item = event.get("item", {})
            item_type = item.get("type")
            if item_type in TOOL_ITEMS:
                result.tool_calls += 1
            if item_type == "file_change":
                # The skill says a review never changes the file. Worth
                # recording: it is the difference between a model that reviewed
                # the invoices and one that "fixed" them.
                for change in item.get("changes", []):
                    if "invoices.csv" in change.get("path", ""):
                        result.edited_fixture = True

        elif kind == "turn.completed":
            usage = event.get("usage", {})
            result.input_tokens = usage.get("input_tokens", 0)
            result.output_tokens = usage.get("output_tokens", 0)

        elif kind == "turn.failed":
            result.status = "failed"
            result.error = event.get("error", {}).get("message", "")[:400]

        elif kind == "error":
            result.status = "failed"
            result.error = event.get("message", "")[:400]

    result.calls_tools = result.tool_calls > 0

    findings, _aside = split_findings(message)
    reported = rows_mentioned(findings)

    result.found = sorted(reported & set(BROKEN_ROWS))
    result.false_positives = sorted(reported & set(CLEAN_ROWS))

    for row in result.found:
        # "Cited" is row *and* rule. The row is why we are in this loop; the
        # rule has to be attached to it, not merely somewhere in the document.
        window = window_around(findings, row)
        if not re.search(RULE_WORDS[row], window, re.I):
            result.cited[str(row)] = CITED_NONE
        elif re.search(RULE_QUOTES[row], window, re.I) or QUOTE_MARKERS.search(window):
            result.cited[str(row)] = CITED_QUOTED
        else:
            result.cited[str(row)] = CITED_PARAPHRASED

    result.counted = count_claimed(message)
    result.count_line = count_sentence(message)

    return result


# --------------------------------------------------------------------------
# Running one model
# --------------------------------------------------------------------------


def build_fixture(directory: Path) -> None:
    """A clean copy of the two files, for every model.

    Fresh each time because a model that edits the CSV despite being told not
    to would otherwise hand every model after it a different task.
    """
    if directory.exists():
        shutil.rmtree(directory)
    directory.mkdir(parents=True)
    (directory / "invoices.csv").write_text(INVOICES_CSV, encoding="utf-8")
    (directory / "rules.md").write_text(RULES_MD, encoding="utf-8")


def run_model(model: str, binary: str, out: Path, timeout: int, extra: list[str]) -> Result:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "_", model)
    workspace = out / "runs" / slug
    fixture = workspace / "fixture"
    build_fixture(fixture)

    last_message = workspace / "last-message.txt"
    events_path = workspace / "events.jsonl"
    stderr_path = workspace / "stderr.txt"

    command = [
        binary,
        "exec",
        "--skip-git-repo-check",
        "--sandbox",
        "workspace-write",
        "--json",
        "--color",
        "never",
        "-C",
        str(fixture),
        "-m",
        model,
        "-o",
        str(last_message),
        *extra,
        PROMPT,
    ]

    result = Result(model=model)
    started = time.time()

    try:
        with events_path.open("w", encoding="utf-8") as events_file, stderr_path.open(
            "w", encoding="utf-8"
        ) as stderr_file:
            subprocess.run(
                command,
                stdout=events_file,
                stderr=stderr_file,
                timeout=timeout,
                check=False,
            )
    except FileNotFoundError:
        result.status = "missing-binary"
        result.error = f"{binary} not found"
        return result
    except subprocess.TimeoutExpired:
        result.status = "timeout"
        result.error = f"no answer within {timeout}s"
        result.seconds = time.time() - started
        return result

    result.seconds = time.time() - started

    events: list[dict] = []
    for line in events_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue

    message = ""
    if last_message.exists():
        message = last_message.read_text(encoding="utf-8", errors="replace")
    if not message:
        # `-o` writes nothing when the turn never reached an answer. Fall back
        # to the last agent message in the stream so a partial run is still
        # scored on whatever it did manage to say.
        for event in events:
            item = event.get("item", {})
            if event.get("type") == "item.completed" and item.get("type") == "agent_message":
                message = item.get("text", "")

    if not events and result.status == "ok":
        result.status = "failed"
        stderr_tail = stderr_path.read_text(encoding="utf-8", errors="replace").strip()
        result.error = stderr_tail[-400:] or "no events on stdout"

    return score(result, events, message)


# --------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------

TICK, CROSS, UNSURE = "yes", "no", "?"


def mark(value: bool | None) -> str:
    if value is None:
        return UNSURE
    return TICK if value else CROSS


def table(results: list[Result], runtime: str) -> str:
    lines = [
        "| Model | Runtime | Calls tools | Found 3/3 | Cited | Counted |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for result in sorted(results, key=lambda item: item.model):
        if not result.ran:
            lines.append(
                f"| `{result.model}` | {runtime} | — | — | — | — |"
                f"  <!-- {result.status}: {result.error[:120]} -->"
            )
            continue
        lines.append(
            f"| `{result.model}` | {runtime} | {mark(result.calls_tools)} | "
            f"{mark(result.found_all)} | {mark(result.cited_all)} | "
            f"{mark(result.counted_right) if result.counted is not None else UNSURE} |"
        )
    return "\n".join(lines)


def review(result: Result) -> str:
    """Everything needed to confirm or overturn one row, in one block."""
    if not result.ran:
        return f"  {result.status}: {result.error[:200]}"

    lines = []
    tools = f"{result.tool_calls} tool call{'s' if result.tool_calls != 1 else ''}"
    lines.append(f"  calls tools  {mark(result.calls_tools):3}  {tools}")

    found = ", ".join(str(row) for row in result.found) or "none"
    detail = f"reported rows {found} of 2, 5, 6"
    if result.false_positives:
        detail += f"; also reported {', '.join(str(r) for r in result.false_positives)}"
        detail += " (rows that break nothing)"
    lines.append(f"  found 3/3    {mark(result.found_all):3}  {detail}")

    if not result.cited:
        detail = "nothing to cite"
    else:
        loose = [row for row, how in result.cited.items() if how == CITED_PARAPHRASED]
        absent = [row for row, how in result.cited.items() if how == CITED_NONE]
        parts = []
        if absent:
            parts.append(f"row {', '.join(absent)} names no rule")
        if loose:
            parts.append(f"row {', '.join(loose)} gives the rule in its own words")
        detail = "; ".join(parts) or "every finding quotes its rule"
    lines.append(f"  cited        {mark(result.cited_all):3}  {detail}")

    if result.counted is None:
        detail = "no coverage line found"
    else:
        detail = f"says {result.counted} rows — {result.count_line[:90]}"
    counted = mark(result.counted_right) if result.counted is not None else UNSURE
    lines.append(f"  counted      {counted:3}  {detail}")

    if result.edited_fixture:
        lines.append("  note         !    edited invoices.csv; a review must not change the file")

    lines.append(
        f"  {result.seconds:.0f}s, {result.input_tokens} in / {result.output_tokens} out"
    )
    return "\n".join(lines)


# --------------------------------------------------------------------------


def models_from_ollama() -> list[str]:
    """Whatever is installed, named the way Ollama names it.

    Taken from the runtime rather than written down, because a tag that is off
    by a suffix produces a row about a model nobody has.
    """
    try:
        listed = subprocess.run(
            ["ollama", "list"], capture_output=True, text=True, timeout=30, check=False
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return []
    models = []
    for line in listed.stdout.splitlines()[1:]:
        name = line.split()[0] if line.split() else ""
        if name:
            models.append(name)
    return models


def read_models_file(path: Path) -> list[str]:
    models = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            models.append(line)
    return models


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run the model-compatibility task across many models.",
    )
    parser.add_argument("-m", "--model", action="append", default=[], help="repeatable")
    parser.add_argument("--models-file", type=Path, help="one model per line, # for comments")
    parser.add_argument("--from-ollama", action="store_true", help="use every installed tag")
    parser.add_argument("--binary", default="opencli", help="default: opencli on PATH")
    parser.add_argument("--out", type=Path, default=Path("model-checks"))
    parser.add_argument("--timeout", type=int, default=600, help="seconds per model")
    parser.add_argument("--runtime", default="Ollama", help="named in the table")
    parser.add_argument("--report", action="store_true", help="rebuild from saved results")
    parser.add_argument(
        "--exec-arg", dest="extra", action="append", default=[],
        help="passed through to opencli exec, repeatable (e.g. --exec-arg --profile=local)",
    )
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    saved = args.out / "results.json"

    if args.report:
        if not saved.exists():
            print(f"nothing saved at {saved}", file=sys.stderr)
            return 1
        results = [Result(**{
            key: value for key, value in row.items()
            if key in Result.__dataclass_fields__
        }) for row in json.loads(saved.read_text(encoding="utf-8"))]
        print(table(results, args.runtime))
        return 0

    models = list(args.model)
    if args.models_file:
        models += read_models_file(args.models_file)
    if args.from_ollama:
        models += models_from_ollama()
    models = list(dict.fromkeys(models))

    if not models:
        parser.error("no models given: use -m, --models-file or --from-ollama")

    binary = shutil.which(args.binary) or args.binary
    print(f"{len(models)} model(s) · {binary} · results under {args.out}/\n")

    results: list[Result] = []
    for index, model in enumerate(models, start=1):
        print(f"[{index}/{len(models)}] {model}", flush=True)
        result = run_model(model, binary, args.out, args.timeout, args.extra)
        results.append(result)
        print(review(result) + "\n", flush=True)

        if result.status == "missing-binary":
            print(
                f"{args.binary} is not on PATH. Build it with\n"
                f"  cargo build --release -p opencli-cli\n"
                f"and pass --binary opencli-rs/target/release/opencli",
                file=sys.stderr,
            )
            return 1

        # Written after every model, not at the end: a batch of thirty local
        # models runs for hours and something will interrupt it.
        saved.write_text(
            json.dumps([item.to_dict() for item in results], indent=2) + "\n",
            encoding="utf-8",
        )

    print("\n" + table(results, args.runtime))
    print(f"\nRaw output per model: {args.out}/runs/<model>/")
    print("Read last-message.txt before pasting a row into the README.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
