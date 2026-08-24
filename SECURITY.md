# Security

## Scope

This repository is a **portfolio and demonstration project** for a fictional
company. It is not deployed to any production org and holds no real customer,
partner or payment data. Every Quote, Opportunity, Task and Reseller record in
`scripts/` and in the test classes is fabricated, and every email address uses
an `example.com` domain reserved for documentation (RFC 2606).

## What is deliberately absent

- **No credentials of any kind.** There are no API keys, tokens, passwords,
  connected-app secrets or Named Credentials in this repository, in the working
  tree or in the git history.
- **No org identifiers.** No org IDs, instance URLs, usernames or session
  information are committed.
- **No external callouts.** Neither feature in this project calls an external
  system, so there is no endpoint to secure and no secret to store.

## Platform security posture

- Every Apex class is declared `with sharing`, so record access follows the
  running user's sharing rules rather than running in system context.
- Object and field access is granted through two explicit permission sets
  (`Reseller_Management`, `Task_Rollup`) rather than by widening profiles.
- Apex exposed to Lightning is limited to the four `@AuraEnabled` methods on
  `QuotePdfService` and the read method on `OpportunityTaskProgressController`.
  Each takes a record Id and queries it directly; none accepts a caller-supplied
  SOQL fragment.
- The PDF is produced in the browser and uploaded through Apex, so the payload
  is written under the current user's permissions.

## Reporting a problem

If you find a security-relevant mistake in this code — including a pattern that
would be unsafe if copied into a real org — please open an issue, or contact
the author via https://mustafaaksu.dev. There is no bug bounty; this is a
portfolio repository, and corrections are genuinely welcome.
