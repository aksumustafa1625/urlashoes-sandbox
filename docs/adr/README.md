# Architecture Decision Records

Each file records one decision that shaped this project: what the constraint
was, what was chosen, what else was on the table, and what the choice costs.
They are written after the fact but from the code and the commit history, not
from memory — every claim points at a file you can open.

## Index

| # | Decision | Why it is here |
|---|---|---|
| [001](ADR-001-kevin-ohara-triggerhandler.md) | Triggers route through the Kevin O'Hara handler framework | Recursion control and testable helpers, for free |
| [002](ADR-002-client-side-pdf-jspdf.md) | The Quote PDF renders in the browser with jsPDF | Visualforce cannot render a PDF from a trigger context |
| [003](ADR-003-change-signature-polling.md) | Regeneration is driven by a computed change signature | Lightning Data Service misses line-item roll-ups |
| [004](ADR-004-version-from-attachment-name.md) | The version number is derived from existing attachment names | A counter field is a second source of truth that drifts |
| [005](ADR-005-aggregateresult-rollup-over-native.md) | Task counts roll up through one aggregate query | `WhatId` is polymorphic, so no roll-up summary is possible |
| [006](ADR-006-key-prefix-filtering.md) | Opportunity Tasks are identified by key prefix | The Id already answers the question a describe call would |

## The pair worth reading together

**ADR-002** here and **ADR-008** in the sibling
[TechnoStore](https://github.com/aksumustafa1625/TechnoStore) project answer the
same nominal question — how do we produce a branded PDF — and reach opposite
conclusions. TechnoStore renders server-side with Visualforce and Flying Saucer;
this project renders client-side with jsPDF. Neither is the better technique in
general. The constraints differ, and the ADRs say how.

## Format

Status · Date · Author · Context · Decision · Alternatives Considered ·
Consequences · References.

The same structure is used across the sibling projects, so a reader moving
between repositories reads the same shape each time.
