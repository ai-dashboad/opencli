//! Departments that work the moment they are created.
//!
//! A department, three bots and a duty apiece can all be typed in by hand, and
//! nobody does. The first thing anyone wants from something like this is to
//! see it do one real piece of work — not to fill in six forms and then find
//! out whether the rules they guessed at were the right ones.
//!
//! So a template brings the bots, their jobs, their duties and the thresholds,
//! and it brings **files for them to work on**. That last part is the one that
//! is easy to leave out and the only one that decides whether the first run
//! does anything: an instruction to reconcile a ledger, in an empty directory,
//! produces a polite explanation that there is no ledger. A test here holds
//! every template to it — every duty must name a file that exists once the
//! template has been applied.
//!
//! The two offered are the two that need nothing connected, which is also why
//! they are the two worth offering first: engineering and finance both keep
//! their material on the machine already, and both are places where sending it
//! to somebody's cloud is the objection rather than the price.

use std::path::Path;

use crate::bots;
use crate::config::department_workspace;
use crate::duties;
use crate::projects;

/// A bot a template brings, with the duty it comes to do.
pub struct BotTemplate {
    pub name: &'static str,
    pub job: &'static str,
    pub duties: &'static [DutyTemplate],
}

pub struct DutyTemplate {
    pub name: &'static str,
    pub what: &'static str,
    /// How to decide, and the numbers that decide it.
    pub rules: &'static str,
    /// What obliges it to stop and ask.
    pub escalate_when: &'static str,
    pub interval_seconds: u64,
}

/// A file a template writes so its duties have something to work on.
pub struct SampleFile {
    pub name: &'static str,
    pub contents: &'static str,
}

pub struct DepartmentTemplate {
    pub id: &'static str,
    pub name: &'static str,
    pub description: &'static str,
    /// Standing instructions every bot in the department is given.
    pub instructions: &'static str,
    pub bots: &'static [BotTemplate],
    pub samples: &'static [SampleFile],
}

const LEDGER: &str = "\
date,reference,description,amount
2026-08-03,INV-1001,Northwind Ltd,1200.00
2026-08-05,INV-1002,Baxter & Sons,842.50
2026-08-09,INV-1003,Ridgeway Supplies,3800.00
2026-08-12,INV-1004,Halcyon Media,275.00
2026-08-15,INV-1005,Northwind Ltd,640.00
2026-08-19,INV-1006,Tolman Freight,1590.25
2026-08-24,INV-1007,Baxter & Sons,98.00
";

// Three deliberate differences, so a first run finds something rather than
// reporting that everything matched: INV-1003 is short by 3800 (never paid),
// INV-1006 arrived 25 short, and there is a payment nobody invoiced.
const STATEMENT: &str = "\
date,reference,amount
2026-08-04,INV-1001,1200.00
2026-08-06,INV-1002,842.50
2026-08-13,INV-1004,275.00
2026-08-16,INV-1005,640.00
2026-08-20,INV-1006,1565.25
2026-08-22,UNMATCHED-PAYMENT,410.00
2026-08-25,INV-1007,98.00
";

const OVERDUE: &str = "\
customer,contact,invoice,amount,due,chased
Ridgeway Supplies,ap@ridgeway.example,INV-1003,3800.00,2026-08-23,0
Tolman Freight,accounts@tolman.example,INV-1006,25.00,2026-08-29,1
";

const SAMPLE_SERVICE: &str = "\
# sample-service

A tiny service kept here so a bot has something real to read on its first run.
Two endpoints, one of which has a bug: `/total` sums the wrong column.
";

const SAMPLE_MAIN: &str = "\
import csv


def load(path):
    with open(path) as handle:
        return list(csv.DictReader(handle))


def total(rows):
    # Bug: sums the due date column instead of the amount.
    return sum(float(row[\"due\"]) for row in rows)


def overdue(rows, on):
    return [row for row in rows if row[\"due\"] < on]
";

const QUESTIONS: &str = "\
asked,customer,question
2026-08-28,Northwind Ltd,Does the 900W model fit a standard 60cm cabinet?
2026-08-29,Halcyon Media,My order says delivered and nothing arrived.
2026-08-29,Baxter & Sons,Can I change the delivery address after paying?
2026-08-30,Ridgeway Supplies,I want to return two of the four I bought.
";

const CONTACTS: &str = "\
name,email,bought,last_contact
Alice Fenn,alice@fenn.example,900W blender,2026-07-14
Marcus Oyelaran,marcus@oyelaran.example,900W blender,2026-08-02
Dana Whitfield,dana@whitfield.example,Spare jug,2026-06-30
Priya Raman,priya@raman.example,900W blender; spare jug,2026-08-19
";

const ORDERS: &str = "\
order,placed,customer,item,status,carrier_ref
SO-2201,2026-08-18,Northwind Ltd,900W blender,shipped,TR889201
SO-2202,2026-08-19,Halcyon Media,Spare jug,shipped,TR889244
SO-2203,2026-08-20,Baxter & Sons,900W blender,unshipped,
SO-2204,2026-08-21,Priya Raman,900W blender,shipped,TR889310
SO-2205,2026-08-26,Ridgeway Supplies,900W blender x4,unshipped,
";

const NOTES: &str = "\
# Weekly sync, 2026-08-29

Present: Ada, Ben, Chi.

- The 900W listing photo is wrong on two channels. Ben to fix by Tuesday.
- Returns are up; Chi thinks it is the cabinet-fit question. Nobody owns this yet.
- We agreed to stop discounting the spare jug.
- Ada asked whether we can ship to Ireland. Left open.
";

const APPLICANTS: &str = "\
name,applied,years,notes
Rae Ferreira,2026-08-20,6,Wrote the returns tooling at a previous shop
Sam Iversen,2026-08-22,2,Strong on data; no customer-facing experience
Nell Okonkwo,2026-08-25,9,Ran a support team of four
";

pub static TEMPLATES: &[DepartmentTemplate] = &[
    DepartmentTemplate {
        id: "engineering",
        name: "Engineering",
        description: "Reading a codebase, making a change and checking it, and watching \
                      for what breaks.",
        instructions: "Explain what you changed and why. Prefer reading the file over \
                       recalling it. Say plainly what you could not verify.",
        bots: &[
            BotTemplate {
                name: "Reader",
                job: "Read code you have not seen before and explain it plainly: what it \
                      is for, where to start reading, and how the parts fit. Answer with \
                      the file and line, not from memory.",
                duties: &[],
            },
            BotTemplate {
                name: "Reviewer",
                job: "Review changes for correctness before anyone else reads them. Say \
                      what would break and under what input, rather than listing style \
                      preferences.",
                duties: &[DutyTemplate {
                    name: "Look over sample-service",
                    what: "Read sample-service/main.py and report anything that would \
                           give a wrong answer. Name the function and the input that \
                           breaks it.",
                    rules: "Report only what would produce a wrong result or a crash. \
                            Style and naming are not findings.",
                    escalate_when: "A fix would change behaviour that something else \
                                    might rely on.",
                    interval_seconds: 86_400,
                }],
            },
            BotTemplate {
                name: "On call",
                job: "Watch for things that have broken and work out what broke them. \
                      Report the change and the person, not just the failure.",
                duties: &[],
            },
        ],
        samples: &[
            SampleFile {
                name: "sample-service/README.md",
                contents: SAMPLE_SERVICE,
            },
            SampleFile {
                name: "sample-service/main.py",
                contents: SAMPLE_MAIN,
            },
        ],
    },
    DepartmentTemplate {
        id: "finance",
        name: "Finance",
        description: "Reconciling, chasing what is owed, and explaining what moved — on \
                      this machine, where the numbers already are.",
        instructions: "Show the figures you worked from. Never guess at an amount: if a \
                       row is unclear, say which row and why.",
        bots: &[
            BotTemplate {
                name: "Reconciler",
                job: "Match the ledger against the bank statement and account for every \
                      difference. A difference you cannot explain is a finding, not a \
                      rounding error.",
                duties: &[DutyTemplate {
                    name: "Daily reconciliation",
                    what: "Compare ledger.csv against statement.csv. List every line \
                           that does not match, with the reference and the amount, and \
                           say what you think each one is.",
                    rules: "A difference under 100 may be recorded and left. Anything \
                            over that goes in the report with what you think happened.",
                    escalate_when: "A single difference is over 500, or a payment \
                                    arrived that matches no invoice.",
                    interval_seconds: 86_400,
                }],
            },
            BotTemplate {
                name: "Chaser",
                job: "Keep track of what is owed and write the letters that ask for it. \
                      Polite the first time, specific every time.",
                duties: &[DutyTemplate {
                    name: "Chase what is overdue",
                    what: "Read overdue.csv and draft one chasing email per customer, \
                           saving each as a file. Do not send anything.",
                    rules: "First chase is a reminder. Second is firmer and names the \
                            days overdue. Never threaten.",
                    escalate_when: "An invoice has been chased twice already, or is \
                                    over 1000 and more than 30 days late.",
                    interval_seconds: 604_800,
                }],
            },
            BotTemplate {
                name: "Bookkeeper",
                job: "Turn receipts and invoices into rows: date, reference, amount, \
                      what it was for. Say which document each row came from.",
                duties: &[],
            },
        ],
        samples: &[
            SampleFile {
                name: "ledger.csv",
                contents: LEDGER,
            },
            SampleFile {
                name: "statement.csv",
                contents: STATEMENT,
            },
            SampleFile {
                name: "overdue.csv",
                contents: OVERDUE,
            },
        ],
    },
    DepartmentTemplate {
        id: "support",
        name: "Support",
        description: "Answering what customers ask, keeping track of who is still \
                      waiting, and noticing what they keep asking about.",
        instructions: "Answer the question that was asked. Where you are unsure of a \
                       fact about the product, say so rather than inventing one.",
        bots: &[
            BotTemplate {
                name: "Front desk",
                job: "Draft replies to what customers ask: plain, specific, and in the \
                      language they wrote in. Never promise a date you cannot see.",
                duties: &[DutyTemplate {
                    name: "Answer what came in",
                    what: "Read questions.csv and draft an answer to each one, saved as \
                           a file per customer. Say which you could not answer and why.",
                    rules: "Refunds and address changes follow the published policy. A \
                            question about a fact you cannot check is escalated, not \
                            guessed.",
                    escalate_when: "Somebody says a delivered order never arrived, or \
                                    asks for anything you have no policy for.",
                    interval_seconds: 3600,
                }],
            },
            BotTemplate {
                name: "Themes",
                job: "Notice what customers keep asking about, and say which of it is a \
                      product problem rather than a support problem.",
                duties: &[DutyTemplate {
                    name: "What are they asking about",
                    what: "Group the questions in questions.csv by what they are really \
                           about, and write the three most common as a short list.",
                    rules: "A theme needs at least two questions behind it. One customer \
                            is an anecdote.",
                    escalate_when: "A theme suggests something is wrong with the product \
                                    rather than the description.",
                    interval_seconds: 604_800,
                }],
            },
        ],
        samples: &[SampleFile {
            name: "questions.csv",
            contents: QUESTIONS,
        }],
    },
    DepartmentTemplate {
        id: "operations",
        name: "Operations",
        description: "Orders, shipments and what has got stuck — checked every day so \
                      nobody finds out from the customer.",
        instructions: "Say which order you mean by its number. An order you are unsure \
                       about is one to list, not one to leave out.",
        bots: &[BotTemplate {
            name: "Fulfilment",
            job: "Watch orders from placed to delivered, and find the ones that have \
                  stopped moving before somebody complains.",
            duties: &[DutyTemplate {
                name: "What has stopped moving",
                what: "Read orders.csv and list every order still unshipped, with how \
                       many days it has been waiting and who it is for.",
                rules: "Unshipped for more than two days is late. Anything shipped with \
                        no carrier reference is stuck, whatever the status says.",
                escalate_when: "An order has been waiting more than five days, or a \
                                customer has already asked about it.",
                interval_seconds: 86_400,
            }],
        }],
        samples: &[SampleFile {
            name: "orders.csv",
            contents: ORDERS,
        }],
    },
    DepartmentTemplate {
        id: "marketing",
        name: "Marketing",
        description: "Writing what goes out, and keeping a list of people warm without \
                      writing to them all the same way.",
        instructions: "Write like a person. No superlatives you could not defend, and \
                       nothing addressed to `Dear Customer`.",
        bots: &[
            BotTemplate {
                name: "Writer",
                job: "Turn one thing worth saying into the posts, emails and copy that \
                      say it — each in the shape its place expects.",
                duties: &[DutyTemplate {
                    name: "Write the week's posts",
                    what: "Read notes.md, pick what is worth telling customers, and \
                           write five short posts as files — one a day.",
                    rules: "One idea per post. Nothing about a fix until it has shipped.",
                    escalate_when: "The only thing worth saying is something that has \
                                    gone wrong.",
                    interval_seconds: 604_800,
                }],
            },
            BotTemplate {
                name: "List",
                job: "Keep track of who bought what and when they were last written to, \
                      so nobody gets the same message twice or nothing for a year.",
                duties: &[DutyTemplate {
                    name: "Who has not heard from us",
                    what: "Read contacts.csv and group people by what they bought and \
                           how long since they were last contacted.",
                    rules: "Six weeks without contact is a gap. Somebody written to in \
                            the last fortnight is left alone.",
                    escalate_when: "More than half the list falls in one group, which \
                                    usually means the data is wrong rather than the \
                                    customers.",
                    interval_seconds: 604_800,
                }],
            },
        ],
        samples: &[
            SampleFile {
                name: "notes.md",
                contents: NOTES,
            },
            SampleFile {
                name: "contacts.csv",
                contents: CONTACTS,
            },
        ],
    },
    DepartmentTemplate {
        id: "people",
        name: "People & admin",
        description: "Applications, meeting notes and the paperwork nobody enjoys — \
                      kept on this machine, where personal data belongs.",
        instructions: "This department handles people's personal information. Never \
                       copy it anywhere it did not come from, and never send it \
                       outside this machine.",
        bots: &[
            BotTemplate {
                name: "Hiring",
                job: "Read applications against what a role actually needs, and write \
                      the questions worth asking each person.",
                duties: &[DutyTemplate {
                    name: "Read what came in",
                    what: "Read applicants.csv and, for each person, write what fits \
                           the role, what does not, and two questions to ask them.",
                    rules: "Judge the experience, not the wording. Say when you cannot \
                            tell from what is written.",
                    escalate_when: "Somebody is clearly worth talking to and clearly \
                                    outside the range that was budgeted.",
                    interval_seconds: 86_400,
                }],
            },
            BotTemplate {
                name: "Minutes",
                job: "Turn what was said into what was decided, who is doing it, and \
                      what was left open.",
                duties: &[DutyTemplate {
                    name: "Decisions and who owns them",
                    what: "Read notes.md and write out the decisions, the actions with \
                           an owner, and anything left open with no owner at all.",
                    rules: "An action with no owner is listed as unowned rather than \
                            given to whoever spoke last.",
                    escalate_when: "Something was decided that nobody was named to do.",
                    interval_seconds: 604_800,
                }],
            },
        ],
        samples: &[
            SampleFile {
                name: "applicants.csv",
                contents: APPLICANTS,
            },
            SampleFile {
                name: "notes.md",
                contents: NOTES,
            },
        ],
    },
];

pub fn find(id: &str) -> Option<&'static DepartmentTemplate> {
    TEMPLATES.iter().find(|template| template.id == id)
}

/// What applying a template produced.
pub struct Applied {
    pub department: projects::Project,
    pub bots: Vec<bots::Bot>,
    pub duties: Vec<duties::Duty>,
}

/// Create the department, hire its bots, give them their duties, and write the
/// files those duties work on.
///
/// Existing files are left alone. Someone applying a template a second time,
/// or into a department they have already been working in, must not have their
/// own `ledger.csv` replaced by the sample one.
pub fn apply(opencli_home: &Path, id: &str) -> std::io::Result<Applied> {
    let template = find(id).ok_or_else(|| {
        std::io::Error::new(
            std::io::ErrorKind::NotFound,
            format!("no template called `{id}`"),
        )
    })?;

    let slug = projects::directory_slug(template.name);
    let cwd = department_workspace(opencli_home, &slug)?;

    for sample in template.samples {
        let path = cwd.join(sample.name);
        if path.exists() {
            continue;
        }
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::write(path, sample.contents)?;
    }

    let department = projects::create(
        opencli_home,
        template.name.to_string(),
        cwd.to_string_lossy().into_owned(),
        template.instructions.to_string(),
        template.description.to_string(),
    )?;

    let mut hired = Vec::new();
    let mut assigned = Vec::new();
    for bot in template.bots {
        let made = bots::create(
            opencli_home,
            department.id.clone(),
            bot.name.to_string(),
            bot.job.to_string(),
        )?;
        for duty in bot.duties {
            let created = duties::create(
                opencli_home,
                made.id.clone(),
                duty.name.to_string(),
                duty.what.to_string(),
                duty.interval_seconds,
            )?;
            // The rules and the stopping condition are what make it a duty
            // rather than a repeating prompt, and `create` does not take them.
            let mut all = duties::load(opencli_home);
            if let Some(stored) = all.iter_mut().find(|stored| stored.id == created.id) {
                stored.rules = duty.rules.to_string();
                stored.escalate_when = duty.escalate_when.to_string();
                assigned.push(stored.clone());
            }
            duties::save(opencli_home, &all)?;
        }
        hired.push(made);
    }

    Ok(Applied {
        department,
        bots: hired,
        duties: assigned,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    /// The files an instruction tells a bot to work on.
    ///
    /// A word with a dot in the middle of it. Crude, and it only has to be
    /// good enough to notice that a template promises `ledger.csv` and never
    /// writes one — which is the failure this exists to catch.
    fn files_named_in(what: &str) -> Vec<String> {
        what.split_whitespace()
            // Trimmed to alphanumerics at both ends, which takes the full
            // stop off the end of a sentence while leaving the dot inside a
            // filename. Keeping `.` as a trimmable-through character was the
            // first attempt, and it dropped every file that ended a sentence —
            // so the check above passed while never looking at them.
            .map(|word| word.trim_matches(|c: char| !c.is_ascii_alphanumeric()))
            .filter(|word| {
                let Some((stem, extension)) = word.rsplit_once('.') else {
                    return false;
                };
                !stem.is_empty()
                    && !extension.is_empty()
                    && extension.chars().all(|c| c.is_ascii_alphanumeric())
            })
            .map(str::to_string)
            .collect()
    }

    #[test]
    fn should_pick_the_filenames_out_of_an_instruction() {
        // The check above is only as good as this. Written wrongly it would
        // find nothing, pass every template, and say nothing was missing.
        assert_eq!(
            files_named_in("Compare ledger.csv against statement.csv."),
            vec!["ledger.csv", "statement.csv"]
        );
        assert_eq!(
            files_named_in("Read sample-service/main.py and report anything."),
            vec!["sample-service/main.py"]
        );
        // Not a file: a sentence ending, and a bare word.
        assert!(files_named_in("Do the thing. Then stop.").is_empty());
    }

    #[test]
    fn should_bring_a_department_its_bots_and_their_duties() {
        let dir = tempdir().expect("tempdir");
        let applied = apply(dir.path(), "finance").expect("apply");

        assert_eq!(applied.department.name, "Finance");
        assert_eq!(applied.bots.len(), 3);
        assert_eq!(applied.duties.len(), 2);
        assert!(applied.duties.iter().all(|duty| !duty.rules.is_empty()));
        assert!(
            applied
                .duties
                .iter()
                .all(|duty| !duty.escalate_when.is_empty()),
            "a duty with no stopping condition is a repeating prompt"
        );
    }

    #[test]
    fn should_give_every_duty_a_file_that_exists_once_applied() {
        // The promise that decides whether a first run does anything. An
        // instruction to reconcile a ledger, in an empty directory, produces a
        // polite explanation that there is no ledger — and a test asserting
        // only that the template "needs no connector" would have passed.
        for template in TEMPLATES {
            let dir = tempdir().expect("tempdir");
            let applied = apply(dir.path(), template.id).expect("apply");
            let cwd = Path::new(&applied.department.cwd);

            for bot in template.bots {
                for duty in bot.duties {
                    let named = files_named_in(duty.what);
                    assert!(
                        !named.is_empty(),
                        "{}/{} names no file to work on",
                        template.id,
                        duty.name
                    );
                    for file in &named {
                        assert!(
                            cwd.join(file).exists(),
                            "{}/{} works on `{file}`, which the template does not write",
                            template.id,
                            duty.name
                        );
                    }
                }
            }
        }
    }

    #[test]
    fn should_write_files_with_something_to_find_in_them() {
        // A reconciliation where everything matches teaches nothing about
        // whether the duty works.
        let dir = tempdir().expect("tempdir");
        let applied = apply(dir.path(), "finance").expect("apply");
        let cwd = Path::new(&applied.department.cwd);

        let ledger = std::fs::read_to_string(cwd.join("ledger.csv")).expect("ledger");
        let statement = std::fs::read_to_string(cwd.join("statement.csv")).expect("statement");
        assert!(
            ledger.contains("INV-1003") && !statement.contains("INV-1003"),
            "there must be something to find"
        );
        assert!(statement.contains("UNMATCHED-PAYMENT"));
    }

    #[test]
    fn should_not_overwrite_files_someone_is_already_working_on() {
        let dir = tempdir().expect("tempdir");
        let first = apply(dir.path(), "finance").expect("apply");
        let ledger = Path::new(&first.department.cwd).join("ledger.csv");
        std::fs::write(&ledger, "mine,not,yours\n").expect("write");

        apply(dir.path(), "finance").expect("apply again");

        assert_eq!(
            std::fs::read_to_string(&ledger).expect("read"),
            "mine,not,yours\n"
        );
    }

    #[test]
    fn should_put_a_department_in_its_own_directory() {
        let dir = tempdir().expect("tempdir");
        let finance = apply(dir.path(), "finance").expect("apply");
        let engineering = apply(dir.path(), "engineering").expect("apply");

        assert!(finance.department.cwd.ends_with("workspace/finance"));
        assert_ne!(finance.department.cwd, engineering.department.cwd);
    }

    #[test]
    fn should_hire_bots_that_can_address_each_other() {
        let dir = tempdir().expect("tempdir");
        let applied = apply(dir.path(), "finance").expect("apply");
        let reconciler = &applied.bots[0];

        let found = bots::resolve(dir.path(), "chaser", &reconciler.department);
        assert!(found.is_some(), "a colleague must be reachable by name");
    }

    #[test]
    fn should_refuse_a_template_that_does_not_exist() {
        let dir = tempdir().expect("tempdir");
        // A name nobody will plausibly add later, since a template called
        // `marketing` did arrive and quietly turned this into a test of
        // nothing until it failed.
        assert!(apply(dir.path(), "no-such-department").is_err());
    }
}
