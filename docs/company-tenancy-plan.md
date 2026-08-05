# eDocument Centre - Company Tenancy Plan

## Goal

Convert the current CHS-branded DocuSeal project into a multi-company eDocument Centre.

Final app identity:

- App name: eDocument Centre
- Future domain: edc.churchfieldhomeservices.ie

Companies:

1. Churchfield Home Services (CHS)
2. Materials Direct (MD)
3. Smart Lotto (SL)
4. Efficient Software Solutions (ESS)

This is not just a multiple-SMTP feature. This is a company-tenancy feature.

Each company should own:

- Users
- Departments
- Templates/forms
- Submissions
- SMTP/email settings
- Branding/logo/theme
- Email sender identity

---

## Core Rules

### Company Tenancy

A user belongs to one company at a time.

A template belongs to one company.

A submission belongs to one company.

A department belongs to one company.

A company's SMTP settings are used when sending documents for that company.

### Department Access

Departments remain inside companies.

Example:

- CHS > HR
- MD > HR

These are separate departments even if the names are the same.

Access should be checked in this order:

1. Company access
2. Department access
3. Role permissions

---

## Recommended Role Model

### Platform Admin

Platform Admins are IT/system-level administrators.

They can manage:

- All companies
- All users
- Company assignment
- Company SMTP settings
- Company branding
- Global eDocument Centre settings
- Emergency troubleshooting across companies

Only a very small number of users should have this permission.

### Company Admin

Company Admins belong to one company.

They can manage only their own company:

- Company users
- Company departments
- Company templates
- Company submissions
- Company SMTP
- Company branding

They cannot access other companies.

### Company Editor

Company Editors belong to one company.

They can create/edit/send templates and submissions inside their company, subject to department access.

### Company Viewer

Company Viewers belong to one company.

They can view records inside their company, subject to department access.

---

## Recommended Data Model

Keep DocuSeal's existing Account model as the hidden/system container.

Add our own Company model as the business tenancy layer.

Structure:

- Account has many Companies
- Company belongs to Account
- User belongs to Company
- Department belongs to Company
- Template belongs to Company
- Submission belongs to Company

Suggested new table:

companies

Suggested fields:

- id
- account_id
- name
- code
- active
- created_at
- updated_at

Initial company records:

- Churchfield Home Services / CHS
- Materials Direct / MD
- Smart Lotto / SL
- Efficient Software Solutions / ESS

Suggested new fields:

- users.company_id
- departments.company_id
- templates.company_id
- submissions.company_id
- users.platform_admin

Need to inspect whether these also need direct company_id fields:

- submitters
- template_folders
- template_sharings
- dynamic_documents
- template_versions
- submission_events

Some records may be safely derived from template/submission company, but this must be reviewed before implementation.

---

## Initial Data Migration Plan

Current live data should initially belong to Materials Direct.

Reason:

- Current live templates are MD templates.
- Only one template has actually been used for a completed form.
- Existing data should not be assigned to CHS just because the current branding says CHS.

Initial migration should:

1. Create the four companies.
2. Assign existing templates to Materials Direct.
3. Assign existing submissions to Materials Direct.
4. Assign existing departments to Materials Direct.
5. Assign existing users to Materials Direct, unless manually changed later.
6. Preserve all existing department relationships.
7. Preserve existing template/submission behavior.

After the Settings UI exists, users can be moved to CHS, SL, ESS, or MD properly.

When moving a user to another company:

- Update users.company_id
- Clear old department assignments
- Require new department assignments inside the new company

---

## Email / SMTP Rules

Email delivery must be based on the company that owns the submission, not only the currently logged-in user.

Correct logic:

submission.company
-> company SMTP config
-> company from-name/from-email
-> send email

Reason:

- Background jobs may send reminders later.
- Completed-document emails may be sent without the original user being active.
- Platform Admins may send documents for another company.
- The document/submission company should control sender identity.

Fallback rule:

If a company SMTP config is missing, temporarily fall back to the existing/global SMTP config until all company SMTP settings are configured.

SMTP password must be stored encrypted, not plain text.

---

## Branding Rules

App-level name:

- eDocument Centre

Company-level branding:

Each company should eventually support:

- Light logo
- Dark logo
- Primary color
- Accent color
- Email logo/header
- Email footer/signature
- Sender display name

Logged-in user experience:

- MD user sees MD branding.
- CHS user sees CHS branding.
- SL user sees SL branding.
- ESS user sees ESS branding.

Public forms/signing pages should use branding based on the template/submission company.

Platform Admin experience can show either:

- Generic eDocument Centre branding, or
- A selected company context.

---

## Phase Plan

### Phase 1 - Company Foundation and Access Isolation

Goal:

Company tenancy works before SMTP and branding changes.

Build:

- Company model
- companies table
- company_id on users/departments/templates/submissions
- platform_admin field/permission
- seed/backfill four companies
- assign existing live data to Materials Direct
- add company scoping to abilities/permissions
- scope templates/dashboard/submissions/users/departments by company
- preserve existing department ACL behavior inside each company

Success criteria:

- Existing templates are assigned to Materials Direct.
- Existing submissions still open/work.
- Users only see their own company data.
- Departments still work inside company.
- Platform Admin can manage all companies.
- Company Admin cannot see other companies.
- No email behavior is changed yet.

### Phase 2 - Settings UI for Companies, Users, and Departments

Goal:

Admins can manage company structure safely.

Build:

- Settings > Companies
- Company create/edit page
- Company dropdown in user form
- Departments belong to selected company
- Department assignment filtered by user company
- Moving a user to another company clears old department assignments
- Company Admin can only manage users/departments inside own company
- Platform Admin can manage all companies

Success criteria:

- Platform Admin can create/edit CHS, MD, SL, ESS.
- Platform Admin can move users between companies.
- Company Admin cannot move users outside their company.
- Department assignment never crosses company boundaries.

### Phase 3 - Per-Company SMTP

Goal:

Emails send from the correct company.

Build:

- Company SMTP settings
- Encrypted SMTP password
- Test email button
- Email sending chooses SMTP from submission.company
- Fallback to global SMTP if company SMTP is missing
- SMTP validation/error handling

Success criteria:

- MD document emails send from MD SMTP.
- CHS document emails send from CHS SMTP.
- SL document emails send from SL SMTP.
- ESS document emails send from ESS SMTP.
- Background/reminder/completed emails use the submission company SMTP.

### Phase 4 - Per-Company Branding

Goal:

Users see their company branding.

Build:

- Company logos
- Company colors
- Navbar branding based on logged-in user company
- Public form branding based on template/submission company
- Email branding/footer based on company
- Default eDocument Centre branding for platform/global pages

Success criteria:

- MD users see MD branding.
- CHS users see CHS branding.
- SL users see SL branding.
- ESS users see ESS branding.
- Public links use the correct company branding.

### Phase 5 - Rename and Domain Change

Goal:

Final public identity.

Change:

- CHS DocuSeal -> eDocument Centre
- chsdocuseal.churchfieldhomeservices.ie -> edc.churchfieldhomeservices.ie

Tasks:

- Update HOST env variable
- Update Nginx Proxy Manager
- Update email link domain
- Update page titles
- Update favicon/logo text
- Optionally redirect old domain to new domain

Success criteria:

- Public URL is edc.churchfieldhomeservices.ie
- Emails contain edc.churchfieldhomeservices.ie links
- Old domain can redirect safely if needed
- App branding says eDocument Centre

---

## Implementation Notes

Do not implement all phases at once.

Build one phase, test it fully, commit it, then continue.

Before each live deployment:

- Backup Docker volume
- Backup container inspect output
- Confirm rollback image or rebuild path
- Test locally first
- Deploy outside busy hours

Most important risk areas:

- Permissions leaking records across companies
- User moving between companies while keeping old departments
- Email sent from wrong company SMTP
- Public form/signing pages using wrong branding
- Background jobs using global SMTP instead of company SMTP