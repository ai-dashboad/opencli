/**
 * The first screen's answer to "what is this for".
 *
 * A blank composer under the words "Ready when you are" hands the question
 * back to the person who opened the app precisely because they did not know.
 * This puts the kinds of work in front of them, each with instructions they
 * can run as they stand — read, clicked, edited, sent.
 *
 * An example is offered as runnable only when it is. Where a service is
 * missing the row says which one and offers to go and connect it, because the
 * alternative is a click that produces a plausible-looking failure and teaches
 * that the agent cannot do the thing it was just told it could.
 */

import { useState } from "react";

import { SCENARIOS, isRunnable, missingFor, type Scenario } from "./scenarios";
import { t } from "./i18n";

export function Scenarios({
  connected,
  onPick,
  onConnect,
}: {
  /** Connectors configured on this machine, by name. */
  connected: string[];
  /** Puts an instruction in the composer, unsent. */
  onPick: (prompt: string) => void;
  onConnect: () => void;
}) {
  // Nothing open to begin with: six headings fit on a screen and read as a
  // menu, where six expanded lists read as a wall and get skipped.
  const [open, setOpen] = useState<string | null>(null);

  return (
    <section className="scenarios">
      <div className="scenarios-head">
        <span>{t("Things it can do for you")}</span>
      </div>
      <ul>
        {SCENARIOS.map((scenario) => (
          <ScenarioRow
            key={scenario.id}
            scenario={scenario}
            open={open === scenario.id}
            connected={connected}
            onToggle={() => setOpen(open === scenario.id ? null : scenario.id)}
            onPick={onPick}
            onConnect={onConnect}
          />
        ))}
      </ul>
    </section>
  );
}

function ScenarioRow({
  scenario,
  open,
  connected,
  onToggle,
  onPick,
  onConnect,
}: {
  scenario: Scenario;
  open: boolean;
  connected: string[];
  onToggle: () => void;
  onPick: (prompt: string) => void;
  onConnect: () => void;
}) {
  return (
    <li className={`scenario${open ? " open" : ""}`}>
      <button className="scenario-head" onClick={onToggle} aria-expanded={open}>
        <strong>{scenario.name()}</strong>
        <em>{scenario.blurb()}</em>
      </button>
      {open ? (
        <div className="scenario-body">
          {scenario.examples.map((example) => {
            const missing = missingFor(example, connected);
            const ready = isRunnable(example, connected);
            return (
              <div className="scenario-example" key={example.prompt()}>
                <button
                  className="try"
                  disabled={!ready}
                  onClick={() => onPick(example.prompt())}
                  title={ready ? t("Put this in the box") : undefined}
                >
                  {example.prompt()}
                </button>
                {ready ? null : (
                  <button className="link needs" onClick={onConnect}>
                    {t("needs {name}", { name: missing.join(", ") })}
                  </button>
                )}
              </div>
            );
          })}
          {scenario.caveat ? <p className="scenario-caveat">{scenario.caveat()}</p> : null}
        </div>
      ) : null}
    </li>
  );
}
