# Contributing

This is a personal portfolio project rather than an open-source product, so
there is no roadmap to volunteer for. Corrections are welcome all the same —
particularly anything that would be wrong or unsafe if copied into a real org.

## What is most useful

- **A mistake in the code.** A missed bulkification path, a sharing declaration
  that should not be there, a test that asserts nothing.
- **A mistake in the reasoning.** The ADRs in [`docs/adr/`](docs/adr/) state why
  each decision was made. If the premise is wrong, the decision is wrong, and
  that is worth more than a patch.
- **A platform change.** These files were written against API 62–65. If a newer
  release makes an approach here obsolete, saying so is a real contribution.

## Working locally

```bash
git clone https://github.com/aksumustafa1625/urlashoes-sandbox.git
cd urlashoes-sandbox
sf org login web --alias urla-sandbox --set-default
sf project deploy start --source-dir force-app --test-level RunLocalTests
sf org assign permset --name Reseller_Management
sf org assign permset --name Task_Rollup
```

A Developer Edition org or a scratch org is enough. Nothing here calls an
external service, so no Named Credential or API key is required.

## House rules for code

- **One trigger per object**, routed through `TriggerHandler`. No logic in the
  trigger body — see [ADR-001](docs/adr/ADR-001-kevin-ohara-triggerhandler.md).
- **Business logic goes in a helper** as static methods over collections, so it
  can be tested without DML.
- **Every production class ships with its own test class.** The project is
  currently 7 for 7 and that ratio is the point, not a coincidence.
- **Bulk-safe by default.** No SOQL or DML inside a loop; assume 200 records.
- **`with sharing`** unless there is a written reason not to.

## Commits

Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `test:`). Say what
changed and why it changed; the diff already says how.

## If you change a decision

Changing an approach documented in an ADR means updating that ADR — either by
amending it or by adding a new record that supersedes it. An ADR that no longer
matches the code is worse than no ADR at all.
