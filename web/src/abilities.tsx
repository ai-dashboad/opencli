/**
 * Everything that gives the agent something it could not do before.
 *
 * Skills and connectors were two entries in the sidebar, split by how they
 * are built — one is instructions on disk, the other a process speaking a
 * protocol. Nobody reaching for either cares about that difference; they are
 * both the same act, which is adding an ability. So they are one page with two
 * tabs, and the search and the filter sit above both.
 *
 * The filter is by department, not by an invented set of industry labels,
 * because departments are a word this product already uses and they answer the
 * question people actually arrive with: *I have just made a Finance
 * department — what should it be connected to?* A catalogue organised by what
 * a server happens to be called cannot answer that.
 */

import { useEffect, useState } from "react";

import type { DepartmentTemplate, OpenCliClient } from "./protocol";
import { ConnectorsView, SkillsView } from "./views";
import { t } from "./i18n";

/** What the two lists below are showing. */
export interface AbilityFilter {
  /** Free text, matched against a name and its one-line description. */
  query: string;
  /** A department id, or null for all of them. */
  department: string | null;
}

/** Whether an entry survives the filter above. */
export function shows(
  filter: AbilityFilter,
  entry: { name: string; description?: string; departments?: string[] },
): boolean {
  const needle = filter.query.trim().toLowerCase();
  if (needle) {
    const haystack = `${entry.name} ${entry.description ?? ""}`.toLowerCase();
    if (!haystack.includes(needle)) return false;
  }
  if (!filter.department) return true;
  // Untagged means it is not claimed by any department, and a filter that
  // silently hid it would be hiding it from everyone at once. Shown, so an
  // entry nobody has categorised is still findable.
  if (!entry.departments?.length) return true;
  return entry.departments.includes(filter.department);
}

export function AbilitiesView({ client, cwd }: { client: OpenCliClient; cwd: string }) {
  const [tab, setTab] = useState<"skills" | "connectors">("connectors");
  const [query, setQuery] = useState("");
  const [department, setDepartment] = useState<string | null>(null);
  const [departments, setDepartments] = useState<DepartmentTemplate[]>([]);

  useEffect(() => {
    // The chips come from the templates rather than from what has been
    // created, so the filter reads the same on a fresh install as on a
    // working one.
    void client
      .listTemplates()
      .then(setDepartments)
      .catch(() => setDepartments([]));
  }, [client]);

  const filter: AbilityFilter = { query, department };

  return (
    <section className="panel abilities">
      <div className="panel-head">
        <h2>{t("Abilities")}</h2>
        <span className="grow" />
        <input
          className="panel-search"
          value={query}
          placeholder={t("Search abilities")}
          onChange={(event) => setQuery(event.target.value)}
        />
      </div>

      <div className="tabs">
        <button className={tab === "connectors" ? "on" : ""} onClick={() => setTab("connectors")}>
          {t("Connectors")}
        </button>
        <button className={tab === "skills" ? "on" : ""} onClick={() => setTab("skills")}>
          {t("Skills")}
        </button>
      </div>

      <div className="chips">
        <button
          className={department === null ? "on" : ""}
          onClick={() => setDepartment(null)}
        >
          {t("All")}
        </button>
        {departments.map((each) => (
          <button
            key={each.id}
            className={department === each.id ? "on" : ""}
            onClick={() => setDepartment(department === each.id ? null : each.id)}
          >
            {each.name}
          </button>
        ))}
      </div>

      {tab === "connectors" ? (
        <ConnectorsView client={client} filter={filter} />
      ) : (
        <SkillsView client={client} cwd={cwd} filter={filter} />
      )}
    </section>
  );
}
