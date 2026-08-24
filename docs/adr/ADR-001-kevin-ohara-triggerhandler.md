# ADR-001: Triggers route through the Kevin O'Hara handler framework, one trigger per object

## Status

**Accepted**

## Date

2026-05-21 (first commit of the project)

## Author

Mustafa Aksu

## Context

Two objects in this project carry automation: `Opportunity` (reseller lookup
resolution) and `Task` (roll-up of counts onto the parent Opportunity). Both
needed logic on insert and update, and the Task roll-up in particular can be
re-entered — updating an Opportunity from a Task trigger is exactly the shape
that produces recursion if nothing guards it.

Writing that logic inline in the trigger body is the default in tutorial code
and the first thing that becomes unmaintainable: context routing, recursion
control and bypass all end up as ad-hoc `if` statements, and none of it is
unit-testable without DML.

## Decision

Adopt **Kevin O'Hara's `sfdc-trigger-framework`** unchanged, and apply a strict
separation:

- **Trigger** — one per object, no logic. It constructs the handler and calls
  `.run()`.
- **Handler** — dispatches trigger contexts (`beforeInsert`, `afterUpdate`, …)
  and nothing else.
- **Helper** — holds the business logic as static methods that take collections
  and return results, with no dependency on `Trigger` context.

`TriggerHandler.cls` and `TriggerHandler_Test.cls` are vendored into the
project rather than installed as a package, so the framework version is pinned
and visible in source control.

## Alternatives Considered

- **Logic directly in the trigger.** Rejected: not unit-testable without DML,
  and recursion control would have to be hand-rolled per object.
- **Flow instead of Apex.** Rejected for the roll-up: the aggregation is a
  single `GROUP BY` query (see ADR-005), which Flow cannot express without
  looping over records — the exact pattern that hits governor limits at volume.
- **A hand-written handler base class.** Rejected: it would reimplement
  recursion control, the bypass API and max-loop protection that this framework
  already provides and that are already covered by its own test class.

## Consequences

- Helpers are testable without inserting records, so the two helper test
  classes assert on the matching and aggregation logic directly.
- `TriggerHandler.bypass()` is available for data loads and for tests that need
  to insert fixtures without firing automation.
- The framework's own test class is carried in the repository, which is why the
  test count includes classes not written for this project's features.
- The same layout is used in the sibling `VoltStreamMobility` project, so the
  two repositories are structurally comparable.

## References

- [`sfdc-trigger-framework`](https://github.com/kevinohara80/sfdc-trigger-framework)
- `force-app/main/default/classes/TriggerHandler.cls`
- `force-app/main/default/triggers/OpportunityTrigger.trigger`, `TaskTrigger.trigger`
