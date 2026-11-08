# Validation status

## Passed in isolated GitHub CI

- Tested plugin commit: `9dd76b2879a04358d670efd7b1f06d9f73625e56`.
- Discourse source: `444e62cc26e96c7da97f08fa45df219f03f60114`.
- Successful run: https://github.com/YangYixin0/discourse-gtiit-primary-email/actions/runs/42508812463
- Backend: **17 examples, 0 failures**.
- Chromium QUnit component tests: passed (escaped text and withheld-field display).
- TypeScript build including plugin model field type assertions: passed.
- Ruby syntax_tree/RuboCop, JS/TS ESLint/Prettier and SCSS Stylelint: passed.
- CI formatter made no changes to the tested commit.
- Source inspection: primary email association, API auth flags, Guardian permissions,
  topic-view bulk preloading and the three core display outlets.

The tests cover member/anonymous requests, valid API and User API keys, invalid API
keys, private-topic denial, profile visibility, account eligibility, disabled setting,
secondary-email exclusion and updated primary email serialization. This is focused
plugin validation, not a complete Discourse regression suite or external audit.

## Remaining before production installation

- Full Horizon pages on desktop/mobile, including actual placement and long addresses.
- English/Chinese page rendering and primary email confirmation/promotion through UI.
- Many-author topic SQL query counts and deployment-specific cache headers/isolation.
- Confirm live registration, email-domain and anonymous-mode settings separately.
- Review pinned production installation, backup and rollback procedure with owner.

## Isolated CNB page acceptance — 2026-11-09

See [the reproducible CNB report](validation/cnb/README.md) and its structured results
and screenshots. Desktop/mobile emulation, both languages, all three display
locations, long addresses, real two-stage email confirmation, old-post refresh,
anonymous/API exclusions, private-topic access and session isolation were checked.
Twenty authors' primary emails loaded in one bulk SQL query. A post-author
long-address truncation was fixed with scoped CSS. At the owner's request, the
three locations now show only the address, with a translated nonvisual label.
The updated Chromium component tests passed (2 tests, 0 failures), and the changed
frontend files passed upstream Prettier, ESLint and Stylelint checks.

These isolated checks cover the first three remaining items above for this test
stack. Physical-device checks and production proxy/cache behavior were not tested.
Production settings, installation approval and deployment remain outstanding.

## Environment boundaries

No production container writes, database queries, package installation, rebuilds,
restarts, SSH changes or root-access changes were performed. Host development files
remain under `/home/codex/gtiit-primary-email-dev`. Ruby/Bundler/Node/pnpm and test
services ran only on disposable GitHub-hosted runners with synthetic test data.

Local and GitHub commit IDs differ because GitHub was initialized and uploaded
through the connected GitHub API. The tested source is identified above. Subsequent
documentation-only updates do not change that tested implementation.

## Suggested interactive validation environment

Use CNB or another disposable development environment at the pinned source revision.
Plan around 4 CPU cores, 8 GB RAM and 15 GB free disk, then measure actual usage.
Provisioning and platform access have not been configured yet. Do not copy production
credentials, accounts or databases into it. The production host has about 4 GB RAM;
do not start a second development stack there by default.
