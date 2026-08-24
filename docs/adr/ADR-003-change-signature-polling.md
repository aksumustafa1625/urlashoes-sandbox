# ADR-003: Regeneration is driven by a computed change signature, not by the record page

## Status

**Accepted**

## Date

2026-05-30

## Author

Mustafa Aksu

## Context

The PDF must reflect the Quote as saved. The natural way to detect a save in a
Lightning Web Component is the Lightning Data Service — `@wire(getRecord)` fires
when the record changes and the component regenerates.

That works for edits to the Quote header. It does not work for the case that
matters most on a quote: **adding, removing or repricing a line item**. Line
items are a child object, and the parent's `Subtotal`, `Tax` and `GrandTotal`
are recalculated by the platform. LDS does not reliably notify the parent
record's component that those totals moved, so a PDF driven purely by
`getRecord` silently goes stale exactly when the money changes.

A second, smaller problem: regenerating on page *open* means every visit
uploads another attachment, so a Quote nobody edited accumulates versions.

## Decision

Compute a **change signature** in Apex and poll it from the component every
three seconds. The signature is a single string built from the fields that
would change the document:

```apex
q.LastModifiedDate.getTime() + '|' + q.Subtotal + '|' + q.Discount + '|'
    + q.Tax + '|' + q.TotalPrice + '|' + q.GrandTotal + '|' + lineCount
```

The component records a baseline signature on mount and regenerates only when a
later poll returns a different value. Opening the page therefore produces
nothing; saving anything that moves a total produces exactly one new version.

For the same reason, `QuotePdfService.getQuoteData` is deliberately **not**
`cacheable=true`. A cached read is the correct default for most `@AuraEnabled`
methods, but this one runs immediately before the document is drawn, and
serving it from the client cache would render a PDF from data the user has
already replaced.

## Alternatives Considered

- **`@wire(getRecord)` alone.** Rejected: misses line-item-driven total changes,
  which is the primary case.
- **A Platform Event published from a QuoteLineItem trigger.** Rejected as
  disproportionate: it adds a trigger, an event definition and an empApi
  subscription to solve what one aggregate query answers. Worth revisiting if
  the polling interval ever becomes a cost.
- **Regenerate on every page load.** Rejected: produces versions that record no
  change, which defeats the point of versioning.
- **Comparing `LastModifiedDate` only.** Rejected: line-item roll-ups do not
  always advance the parent's `LastModifiedDate`, which is precisely the gap
  being closed.

## Consequences

- One lightweight Apex call every three seconds while the component is on
  screen — two SOQL queries, no DML. The interval is cleared on disconnect.
- The number of stored versions equals the number of real changes, which makes
  the attachment list a usable audit trail rather than noise.
- Detection is bounded by the poll interval: a change is picked up within three
  seconds rather than instantly.
- The signature is explicit about what counts as a change. Adding a field to the
  document means adding it to the signature, and that coupling is intentional.

## References

- `QuotePdfService.getQuoteChangeSignature`
- `force-app/main/default/lwc/quotePdfGenerator/quotePdfGenerator.js` — `POLL_INTERVAL_MS`, `pollOnce()`
