# ADR-004: The PDF version number is derived from existing attachment names

## Status

**Accepted**

## Date

2026-05-30

## Author

Mustafa Aksu

## Context

Every regeneration files a new PDF against the Quote, named `<Quote>_v<N>.pdf`.
Something has to decide what `N` is, and the obvious options are a counter field
on Quote or a derivation from what is already stored.

A counter field is a second source of truth. It can drift from reality in both
directions: delete an attachment and the counter still climbs; restore one from
the recycle bin and the counter is behind. Recovering from either means an admin
editing a number to match a file list.

## Decision

Derive the next version by reading the attachments that exist:

```apex
private static final Pattern VERSION_PATTERN = Pattern.compile('_v(\d+)\.pdf$');
```

`getNextVersionNumber` queries the Quote's PDF attachments, parses the trailing
`_v<N>` from each name, and returns the highest found plus one. No field, no
counter, no migration.

## Alternatives Considered

- **An auto-number or numeric field on Quote.** Rejected: a second source of
  truth that can disagree with the file list, with no self-correcting path.
- **Counting attachments.** Rejected: the count is not the version. Deleting
  `_v2` of three files would make the next PDF `_v3` again and overwrite history
  in name if not in fact.
- **A timestamp instead of a version.** Rejected: unambiguous but unreadable;
  "which one is current" becomes a date-parsing exercise for a human.

## Consequences

- The file list *is* the version history. Delete every PDF and numbering restarts
  at 1, which is the behaviour a user would predict.
- Cost is one extra SOQL query per generation, over a small child set.
- The naming convention is now load-bearing: renaming an attachment by hand
  breaks the sequence. The regex is defined once as a constant so the contract
  is visible in one place.
- Filtering is on `ContentType = 'application/pdf'`, so unrelated attachments on
  the Quote are ignored.

## References

- `QuotePdfService.getNextVersionNumber`, `QuotePdfService.parseVersion`
- `QuotePdfServiceTest`
