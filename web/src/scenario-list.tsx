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

/**
 * One kind of work, on a page of its own.
 *
 * The first screen offers six of these in a list, which is enough to be
 * understood and not enough to be started from: what is needed, what is
 * missing, and what to say are three questions, and a row that expands has
 * room for none of them.
 *
 * Starting an instruction from here opens a chat with it already sent, because
 * someone who has come this far has chosen the work rather than an example of
 * it. The first screen behaves the other way round, filling the box and
 * leaving it — the difference is whether the click was a choice or a look.
 */
export function ScenarioView({
  scenario,
  connected,
  onRun,
  onConnect,
}: {
  scenario: Scenario;
  connected: string[];
  /** Opens a chat and sends this instruction. */
  onRun: (prompt: string) => void;
  onConnect: () => void;
}) {
  const needs = [...new Set(scenario.examples.flatMap((example) => example.needs ?? []))].sort();

  return (
    <div className="panel">
      <header className="panel-head">
        <h2>{scenario.name()}</h2>
        <p>{scenario.blurb()}</p>
      </header>

      {scenario.caveat ? (
        <p className="scenario-caveat standalone">{scenario.caveat()}</p>
      ) : null}

      <section className="panel-section">
        <h3>{t("Ask for it like this")}</h3>
        <ul className="scenario-asks">
          {scenario.examples.map((example) => {
            const ready = isRunnable(example, connected);
            const missing = missingFor(example, connected);
            return (
              <li key={example.prompt()}>
                <button className="ask" disabled={!ready} onClick={() => onRun(example.prompt())}>
                  <span>{example.prompt()}</span>
                  {ready ? (
                    <em>{t("Start")}</em>
                  ) : (
                    <em className="blocked">{t("needs {name}", { name: missing.join(", ") })}</em>
                  )}
                </button>
              </li>
            );
          })}
        </ul>
      </section>

      {needs.length > 0 ? (
        <section className="panel-section">
          <h3>{t("Services this can use")}</h3>
          <p className="panel-note">
            {t(
              "Everything above that needs no service works as it is. These open up the rest.",
            )}
          </p>
          <ul className="scenario-needs">
            {needs.map((need) => {
              const have = isRunnable({ prompt: () => "", needs: [need] }, connected);
              return (
                <li key={need}>
                  <strong>{need}</strong>
                  {have ? (
                    <em className="ready">{t("connected")}</em>
                  ) : (
                    <button className="link" onClick={onConnect}>
                      {t("connect")}
                    </button>
                  )}
                </li>
              );
            })}
          </ul>
        </section>
      ) : null}
    </div>
  );
}
