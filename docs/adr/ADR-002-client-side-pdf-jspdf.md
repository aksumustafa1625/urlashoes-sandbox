# ADR-002: The Quote PDF is rendered in the browser with jsPDF, not by Visualforce

## Status

**Accepted**

## Date

2026-05-30

## Author

Mustafa Aksu

## Context

The requirement was that saving a Quote produces a branded PDF and files it
against the record, without a user pressing "print".

The obvious Salesforce answer is `Visualforce renderAs="PDF"`. It is the answer
this same author reached for in the sibling TechnoStore project — see
TechnoStore ADR-008, which selects Visualforce plus Flying Saucer for three
branded document surfaces. It is a good answer *there*, where the documents are
invoices and contracts that must render identically for every recipient and are
generated server-side as part of an order flow.

It is the wrong answer *here*, and the reason is mechanical rather than
aesthetic: rendering a Visualforce PDF requires a `PageReference`, and
`PageReference.getContentAsPDF()` cannot be called from a trigger context. A
Quote-save-triggered PDF therefore cannot be produced by an Apex trigger at all.
Working around that means an asynchronous hop — Queueable or Platform Event —
purely to obtain a context in which Visualforce may render, which adds a
failure surface and a delay for a document the user is waiting to see.

## Decision

Render the PDF **client-side in the LWC** using the `jsPDF` library, loaded from
a static resource via `lightning/platformResourceLoader`:

```js
import { loadScript } from 'lightning/platformResourceLoader';
import jsPdfResource from '@salesforce/resourceUrl/jsPDF';
```

Apex keeps the two jobs the browser cannot do: reading the Quote and its line
items (`QuotePdfService.getQuoteData`), and writing the finished bytes back as
an Attachment (`QuotePdfService.uploadPdf`). Layout, typography and branding
live in the component.

The LWC does not generate on page open. It polls a change signature and
generates only when the record has actually been saved (see ADR-003).

## Alternatives Considered

- **Visualforce `renderAs="PDF"` triggered asynchronously.** Rejected: a
  Queueable or Platform Event exists only to escape the trigger-context
  restriction, and the user waits on an asynchronous job for a document that
  should be immediate.
- **A "Generate PDF" button the user presses.** Rejected: the requirement was
  that the document keeps itself current with the record, not that a user
  remembers to refresh it.
- **A third-party PDF service via callout.** Rejected: it introduces an
  external dependency, a Named Credential and a secret to manage, for output
  that a 100 KB static resource produces locally.

## Consequences

- No Visualforce page, no controller and no asynchronous machinery for this
  feature. The whole path is LWC → Apex → Attachment.
- The PDF is produced under the running user's session, so what they see is
  what is stored.
- Layout is JavaScript rather than markup, which is less familiar to a
  Salesforce-only reviewer and is the main cost of this decision.
- `jsPDF` is vendored as a static resource, so its version is pinned and its
  MIT license travels with the repository.
- The contrast with TechnoStore ADR-008 is deliberate and worth reading as a
  pair: the same author, the same nominal problem, two different constraints,
  two different answers.

## References

- `force-app/main/default/lwc/quotePdfGenerator/quotePdfGenerator.js`
- `force-app/main/default/classes/QuotePdfService.cls`
- `force-app/main/default/staticresources/jsPDF.js`
- `docs/Quote_PDF_Architecture.html` (English), `docs/Quote_PDF_Mimari_TR.html` (Turkish)
- TechnoStore `docs/adr/ADR-008-flying-saucer-vf-pdf.md` — the opposite call, in a different context
