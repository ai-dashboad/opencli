/**
 * What the bots are doing between themselves, and what they are waiting on.
 *
 * Two things a person needs and could not get anywhere else. A background run
 * started by another bot arrives in the queue with no visible reason; the only
 * record of who asked and why was inside a transcript nobody reads, so a
 * cascade that went wrong at the second hop looked exactly like one that went
 * wrong at the fifth. And a bot that stopped to ask stays stopped until it is
 * answered, which is only bearable if the questions are somewhere you can see
 * all of them at once.
 *
 * Questions come first on the page, because they are the part that is blocked
 * on a person. Chains are a record; a question is a request.
 */

import { useCallback, useEffect, useState } from "react";

import type { Chain, Escalation, Handoff, OpenCliClient } from "./protocol";
import { t } from "./i18n";
import { ago } from "./views";

export function BotsView({ client }: { client: OpenCliClient }) {
  const [questions, setQuestions] = useState<Escalation[]>([]);
  const [chains, setChains] = useState<Chain[]>([]);
  const [maxHops, setMaxHops] = useState(0);
  const [open, setOpen] = useState<string | null>(null);
  const [hops, setHops] = useState<Handoff[]>([]);
  const [answering, setAnswering] = useState<string | null>(null);
  const [draft, setDraft] = useState("");
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    try {
      const [asked, listed] = await Promise.all([
        client.listQuestions(),
        client.listChains(),
      ]);
      setQuestions(asked);
      setChains(listed.chains);
      setMaxHops(listed.maxHops);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [client]);

  useEffect(() => {
    void reload();
  }, [reload]);

  const openChain = useCallback(
    async (chain: string) => {
      if (open === chain) {
        setOpen(null);
        return;
      }
      setOpen(chain);
      setHops(await client.readChain(chain).catch(() => []));
    },
    [client, open],
  );

  const answer = useCallback(
    async (id: string) => {
      if (!draft.trim()) return;
      try {
        await client.answerQuestion(id, draft.trim());
        setAnswering(null);
        setDraft("");
        void reload();
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
      }
    },
    [client, draft, reload],
  );

  return (
    <div className="panel">
      <header className="panel-intro">
        <h2>{t("Bots")}</h2>
        <p>{t("What they are waiting on, and what they set off between themselves.")}</p>
      </header>

      {error ? <p className="panel-error">{error}</p> : null}

      <section className="panel-section">
        <h3>{t("Waiting on you")}</h3>
        {questions.length === 0 ? (
          <p className="panel-note">{t("Nothing is waiting. Every bot is either working or idle.")}</p>
        ) : (
          <ul className="asked">
            {questions.map((question) => (
              <li key={question.id}>
                <div className="asked-head">
                  <strong>{question.question}</strong>
                  <em>{ago(question.askedAt)}</em>
                </div>
                {question.context ? <p className="asked-context">{question.context}</p> : null}
                {/* Stated where the answer is given. A duty that stays stopped
                    until this is answered is the whole reason the question is
                    on a page rather than in a transcript. */}
                <p className="panel-note">
                  {t("This duty will not run again until you answer.")}
                </p>
                {answering === question.id ? (
                  <div className="asked-answer">
                    <textarea
                      value={draft}
                      autoFocus
                      placeholder={t("What should it do?")}
                      onChange={(event) => setDraft(event.target.value)}
                    />
                    <button className="primary" onClick={() => void answer(question.id)}>
                      {t("Answer")}
                    </button>
                    <button
                      className="link"
                      onClick={() => {
                        setAnswering(null);
                        setDraft("");
                      }}
                    >
                      {t("Cancel")}
                    </button>
                  </div>
                ) : (
                  <button className="link" onClick={() => setAnswering(question.id)}>
                    {t("Answer this")}
                  </button>
                )}
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="panel-section">
        <h3>{t("Work passed between bots")}</h3>
        {chains.length === 0 ? (
          <p className="panel-note">
            {t("No bot has handed work to another yet.")}
          </p>
        ) : (
          <ul className="chains">
            {chains.map((chain) => (
              <li key={chain.chain} className={open === chain.chain ? "open" : ""}>
                <button className="chain-head" onClick={() => void openChain(chain.chain)}>
                  <strong>{chain.involved.join(" → ")}</strong>
                  <em>
                    {t("{hops} of {max} hops", { hops: chain.hops, max: maxHops })} ·{" "}
                    {ago(chain.lastAt)}
                  </em>
                  {/* The one worth looking at: it stopped because it ran out of
                      rope, not because it was finished. */}
                  {chain.atTheLimit ? (
                    <span className="pill warn">{t("stopped at the limit")}</span>
                  ) : null}
                </button>
                {open === chain.chain ? (
                  <ol className="chain-hops">
                    {hops.map((hop) => (
                      <li key={hop.id}>
                        <div className="chain-hop-head">
                          <strong>
                            {hop.fromName} → {hop.toName}
                          </strong>
                          <em>{hop.outcome.status}</em>
                        </div>
                        <p className="chain-did">{hop.did}</p>
                        {hop.artifacts.length > 0 ? (
                          <p className="chain-files">{hop.artifacts.join(" · ")}</p>
                        ) : null}
                        <p className="chain-next">{hop.next}</p>
                      </li>
                    ))}
                  </ol>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
