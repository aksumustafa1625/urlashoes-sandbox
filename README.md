# Urla Shoes — Sandbox

> A small, finished Salesforce DX project for a fictional shoe distributor. Two
> features, seven production classes, seven test classes, and a written record of
> every decision behind them. The point of this repository is not scale — it is
> that nothing in it is half-done.

> **How this was built.**
>
> I used Claude to build this repository, the way an engineer today uses an IDE — I would rather say it first than have it asked. The model wrote code; I set the structure, and every decision went through me.
>
> So the question worth asking is not *whether* AI wrote it, but **who decided and who verified.** That record is in [`docs/adr/`](docs/adr/): **6 architecture decision records**, each naming the constraint, the choice, the alternatives rejected, and what rejecting them cost. A model does not turn down three options and price the fourth.
>
> **What this is not:** a demonstration, not a production system with real users. Built alone, so no colleague reviewed it. Every number is mine — please run them yourself.

[![API version](https://img.shields.io/badge/API-66.0-orange)]()
[![Trigger framework](https://img.shields.io/badge/trigger--framework-Kevin%20O%27Hara-blue)](https://github.com/kevinohara80/sfdc-trigger-framework)
[![Tests](https://img.shields.io/badge/tests-37%20methods%20%C2%B7%207%20classes-brightgreen)]()
[![ADRs](https://img.shields.io/badge/ADRs-6-informational)](docs/adr/)

---

## Why this project exists

Portfolio repositories usually argue from size: more objects, more integrations,
more features. Its siblings do that —
[TechnoStore](https://github.com/aksumustafa1625/TechnoStore) runs Quote-to-Cash
through seven external systems, and
[urla-shoes](https://github.com/aksumustafa1625/urla-shoes) carries sixty Apex
classes across nine features.

This one argues the opposite way. It is deliberately small, and everything in it
is complete: every production class has a test class, both features work end to
end, the architecture is written down in two languages, and six ADRs say why
each decision went the way it did. A reviewer can read the whole thing in twenty
minutes and know exactly how the author works.

The two features were also chosen because each one hides a real platform
constraint that the obvious solution runs into. Neither problem is solved the way
a tutorial would solve it, and [`docs/adr/`](docs/adr/) explains why.

---

## The two features

### 1. Quote PDF, versioned and self-maintaining

Saving a Quote produces a branded PDF and files it against the record as
`<Quote>_v<N>.pdf`. Nobody presses a button, and a Quote that has not changed
does not accumulate versions.

The obvious implementation — Visualforce `renderAs="PDF"` — **cannot be used
here**: rendering requires a `PageReference`, which is unavailable in a trigger
context. So the PDF is drawn in the browser with `jsPDF`, and Apex keeps the two
jobs the browser cannot do: reading the Quote, and writing the bytes back.

Change detection has its own trap. Lightning Data Service does not reliably fire
when a *line item* changes the parent totals — which is the moment the document
most needs to be redrawn. So regeneration is driven by a composite change
signature computed in Apex and polled every three seconds.

→ [ADR-002](docs/adr/ADR-002-client-side-pdf-jspdf.md) ·
[ADR-003](docs/adr/ADR-003-change-signature-polling.md) ·
[ADR-004](docs/adr/ADR-004-version-from-attachment-name.md)

### 2. Opportunity task progress

`Score__c` and `Completed_Task__c` on Opportunity hold the total and completed
Task counts, surfaced on a dashboard page by the `opportunityTaskProgress`
component.

A roll-up summary field would be the right answer — and it is **not available**.
Roll-up summaries need a master-detail relationship, and Task reaches Opportunity
through `WhatId`, a polymorphic lookup. So the counts are recomputed with two
aggregate queries per trigger run, a fixed cost whether you edit one record or
load two hundred. They are recomputed rather than incremented, so deletes,
restores and data loads all converge back to the truth.

→ [ADR-005](docs/adr/ADR-005-aggregateresult-rollup-over-native.md) ·
[ADR-006](docs/adr/ADR-006-key-prefix-filtering.md)

---

## Architecture

```
Trigger (routing only)
   └── Handler (context dispatch only)
          └── Helper (business logic, static, collection-in / collection-out)
```

One trigger per object, both routed through the vendored Kevin O'Hara
`TriggerHandler`. Business logic never touches `Trigger` context directly, which
is what makes the helper tests possible without DML —
[ADR-001](docs/adr/ADR-001-kevin-ohara-triggerhandler.md).

| Layer | Component | Role |
|---|---|---|
| Trigger | `OpportunityTrigger`, `TaskTrigger` | Construct the handler, call `.run()` |
| Handler | `OpportunityTriggerHandler`, `TaskTriggerHandler` | Dispatch trigger contexts |
| Helper | `OpportunityResellerHelper`, `TaskRollupHelper` | Matching and aggregation logic |
| Service | `QuotePdfService` | Quote read, version resolution, attachment upload |
| Controller | `OpportunityTaskProgressController` | Read model for the progress component |
| UI | `quotePdfGenerator`, `opportunityTaskProgress` | Lightning Web Components |

Full architecture write-up for the PDF pipeline, with diagrams:
[English](docs/Quote_PDF_Architecture.html) ·
[Türkçe](docs/Quote_PDF_Mimari_TR.html)

---

## Data model

| Object | Fields used | Notes |
|---|---|---|
| `Reseller__c` | `Company_Email__c` | Matched case-insensitively against the Opportunity |
| `Opportunity` | `Reseller__c`, `Reseller_Email__c`, `Score__c`, `Completed_Task__c` | Lookup resolved by trigger; counts maintained by roll-up |
| `Quote` / `QuoteLineItem` | standard | Read for the PDF; never written |
| `Task` | `WhatId`, `Status` | Polymorphic parent — the reason for ADR-005 |

Access is granted through two permission sets, `Reseller_Management` and
`Task_Rollup`, rather than by widening a profile.

---

## Setup

```bash
git clone https://github.com/aksumustafa1625/urlashoes-sandbox.git
cd urlashoes-sandbox

sf org login web --alias urla-sandbox --set-default
sf project deploy start --source-dir force-app --test-level RunLocalTests

sf org assign permset --name Reseller_Management
sf org assign permset --name Task_Rollup

sf org open
```

A Developer Edition or scratch org is sufficient. **No external service is
called**, so there is no Named Credential to configure and no API key to supply.

Then: open a Quote with line items to see the PDF component, and an Opportunity
with related Tasks to see the progress component.

---

## Testing

```bash
sf apex run test --test-level RunLocalTests --code-coverage --result-format human --synchronous
```

**37 test methods across 7 test classes.** Counted from source, August 2026.

Of those, **13 belong to the vendored `TriggerHandler` framework** and ship with
it; **24 cover the code written for this project**. The distinction matters when
reading a coverage number, so it is stated here rather than left to be inferred.

The ratio that matters: **7 production classes, 7 test classes.** Nothing in
`force-app/main/default/classes` is untested.

Tests are layered the same way the code is — helpers are tested directly as
static methods with no DML, handlers are tested through DML so the trigger
actually fires.

---

## Decisions

Six ADRs in [`docs/adr/`](docs/adr/), each stating the constraint, the choice,
what else was considered, and what the choice costs.

The one worth reading against its sibling is
[ADR-002](docs/adr/ADR-002-client-side-pdf-jspdf.md): this project renders PDFs
in the browser, while TechnoStore renders them server-side with Visualforce and
Flying Saucer. Same nominal problem, opposite conclusions, different constraints
— and both are written down.

---

## What this project deliberately is not

- **No managed packages.** No CPQ, no DLRS, no dependency to install. Where a
  package would have been the shortcut, the ADR says so and shows the pattern
  underneath instead.
- **No external integrations.** Nothing calls out; there is no endpoint to secure
  and no secret to store. See [SECURITY.md](SECURITY.md).
- **No AI layer.** Its siblings cover that ground. This one is core platform
  engineering: triggers, bulkification, aggregate queries, Lightning components
  and tests.
- **Not a product.** It models a fictional company and holds no real data.

---

## License

Proprietary — see [LICENSE](LICENSE). Readable and referenceable with
attribution; not licensed for commercial or production use.

The bundled `jsPDF` static resource is third-party MIT-licensed software.
