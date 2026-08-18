CloudSquare Partner Application — Salesforce Case Study

Accepts partner applications in two ways in a public Experience Cloud form and a public
webhook and routes both through one shared Apex service: match an existing
`Account` and create an `Opportunity`, or fall back to creating a `Lead`.

1. Project structure

```
force-app/main/default/
classes/
ApplicationDTO.cls                    # shared input contract (flat)
ApplicationResult.cls                 # shared output contract (LWC)
WebhookResponse.cls                   # output contract (REST/JSON)
ApplicationProcessingService.cls      # Part C — matching and create logic
ApplicationFormController.cls         # Part A — @AuraEnabled entry point
ApplicationWebhook.cls                # Part B — @RestResource entry point
ApplicationProcessingServiceTest.cls  # Part D — required test class
ApplicationFormControllerTest.cls     # extra coverage for Part A
ApplicationWebhookTest.cls            # extra coverage for Part B
lwc/applicationForm/                      # Part A — public form component
objects/
Account/fields/Federal_Tax_Id__c.field-meta.xml
Lead/fields/Federal_Tax_Id__c.field-meta.xml
Lead/fields/Application_Source__c.field-meta.xml
Opportunity/fields/Application_Source__c.field-meta.xml
permissionsets/Application_Portal_Guest_Access.permissionset-meta.xml
```

2. Setup instructions

This repo contains only metadata that deploys via source format. Steps, in order:

1. Deploy the metadata to a sandbox:
   ```
   sf project deploy start --source-dir force-app
   ```
2. Create the Experience Cloud site (Setup, Digital Experiences, New Site),
   using any template that supports Guest access.
   Note the site's domain, e.g. `https://<org>.my.site.com`.
3. Add the `applicationForm` LWC to a public page in Experience Builder
4. Enable guest object/Apex access in Digital Experiences then Administration ,
   Site, General, Public Access Settings opens the Guest User profile.
   Assign the included permission set to that Guest User:
   ```
   Application_Portal_Guest_Access
   ```
5. Activate the site (Digital Experiences, All Sites,Publish).
6. Test the webhook once the site is live and published:
   ```
   curl -X POST https://<org>.my.site.com/services/apexrest/external/applications \
     -H "Content-Type: application/json" \
     -d '{
       "companyName": "cloudsquare",
       "federalTaxId": "BG123456789",
       "contact": {
         "firstName": "test",
         "lastName": "testing",
         "email": "test@example.com",
         "phone": "+359888123456"
       },
       "annualRevenue": 500000
     }'
   ```


3. How it works

Shared service (Part C). `ApplicationProcessingService.processApplication`
is the single source of truth for the matching rule, called identically by both
channels:

1. If `federalTaxId` is provided, match an `Account` on `Federal_Tax_Id__c`
   only (no fallback).
2. Otherwise, match an `Account` on `Name` (exact match).
3. If there is a match found then create an `Opportunity` (`Prospecting`, `CloseDate` = today +
   30 days) on that Account.
4. If there is no match then create a `Lead`.

Both create paths stamp `Application_Source__c`, which the service itself
never decides, each entry point sets it before calling the service, so client
input can never spoof the source.

Community form (Part A). `applicationForm` is a self contained LWC: client
side required field validation via `lightning-input` + `reportValidity()`, a
loading spinner during the Apex call, and a success panel showing the created
record type and Id. It calls `ApplicationFormController.submitApplication`,
which forces `applicationSource = 'Community'` and forwards to the shared
service.

Webhook (Part B) `ApplicationWebhook` is a `global` `@RestResource` at
`/services/apexrest/external/applications`, reachable unauthenticated through
the site's Guest User. It deserializes the nested JSON payload into a private
`WebhookPayload` wrapper, flattens it into the same `ApplicationDTO` the LWC
uses, forces `applicationSource = 'Webhook'`, and calls the same service. HTTP
status is `200` on success and `400` on any validation/processing/parsing
failure; the body is always the `{success, recordType, recordId, message}`
JSON shape from the spec.

Security model. Guest Users don't own the Account/Lead/Opportunity records
they need to read or create, so record-level access is granted narrowly and
explicitly rather than through a broad sharing bypass:
- All SOQL in the service runs `WITH USER_MODE`; all DML runs `insert as user`.
- `Application_Portal_Guest_Access` grants the Guest User: Apex Class Access to
  both entry points, read an "View All" on `Account` (needed because Guest Users
  have no ownership/sharing path to arbitrary Accounts under standard OWD),
  create on `Lead` and `Opportunity`, and field-level read/edit on exactly the
  fields this service touches nothing else and not sure if the guest user license would
  be able to assign a custom permission set, it needs some testing.
- Ran the code through `sf code-analyzer` during development and
  the initial pass flagged 4 High-severity `ApexCRUDViolation` findings on
  unenforced SOQL/DML, which is what drove the `USER_MODE`/permission-set
  design above instead of a `without sharing` shortcut, final pass: 0 High, 0
  Critical findings.

4. Assumptions

- `ApplicationDTO` is flat, matching what the LWC form naturally produces.
  The webhook's nested JSON is parsed into a separate internal
  `WebhookPayload`/`ContactPayload` pair and explicitly converted into the flat
  `ApplicationDTO`, per the spec's "parse the JSON body, convert into
  ApplicationDTO" wording.
- `applicationSource` lives on the DTO, not inferred from the caller, so
  `ApplicationProcessingServiceTest` can exercise both source values by calling
  the service directly (test case 4 in Part D), while the controller/webhook
  still enforce the correct value server-side.
- Matching is literal: "if blank then match by Name" means a *blank*
  `federalTaxId` triggers a Name match, it is not a fallback for a
  `federalTaxId` that fails to find a match. Covered explicitly by
  `testBlankTaxIdDoesNotFallBackToTaxIdMatch`.
- Server-side validation is minimal by design: only `companyName`,
  `lastName`, and `applicationSource` are required at the service layer,
  mirroring Salesforce's own required fields on `Lead` (`Company`, `LastName`).
  Email/phone format and all other "required" front-end fields are enforced by
  the LWC (`lightning-input required` + `reportValidity()`); the service
  doesn't re-validate them so it stays reusable for callers with different UX
  needs (e.g., a future integration that doesn't collect phone).
- `ApplicationProcessingService.processApplication` never throws for
  expected failures (bad input, DML errors, insufficient access), it always
  returns a well-formed `ApplicationResult` with `success = false` and a
  message. Both entry points still wrap their call in a `try/catch` as a safety
  net for truly unexpected runtime errors, converting them to
  `AuraHandledException` (LWC) or a `400` `WebhookResponse` (REST).
- `AuraHandledException` messages are set via `setMessage()` after
  construction, without it, Apex masks the message down to a generic
  "Script thrown exception" both for the client and in test assertions.
- No attachment handling, no duplicate detection beyond the stated matching
  rule.
- Guest User permission set assignment isn't itself deployable as plain
  metadata in every org configuration (Guest User permission set support
  varies by org setup).
