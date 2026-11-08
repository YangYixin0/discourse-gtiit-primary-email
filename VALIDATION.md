# Validation status

## Completed

- Source checkout verified at 444e62cc26e96c7da97f08fa45df219f03f60114.
- Inspected primary email association, serializers, Guardian permissions, API auth
  environment flags, TopicView preloading and Horizon-compatible core outlets.
- Confirmed original user-card/profile/post components are preserved by additive outlets.
- Plugin model field declarations and tracked post field registration included.
- Basic file/content checks and `git diff --check` completed.

## Not passed / not run

- Required `bin/lint --fix` attempted: exits 127 because Ruby is not installed.
- RSpec, QUnit, TypeScript and browser tests NOT RUN; dependencies are unavailable.
- Tests are written but unverified; static review does not establish runtime correctness.
- No live endpoint probing, production database queries or production modifications.

## Proposed test environment (approval required before provisioning here)

Prefer a separate disposable development machine/CI runner with the pinned Discourse
checkout, Ruby/Bundler, Node/pnpm, PostgreSQL, Redis and Chromium. Use synthetic test
accounts and databases only. Allow about 4 CPU cores, 8 GB RAM and 15 GB free disk
as planning capacity, then measure actual usage. Run focused tests serially.
The production host has about 4 GB RAM, so do not start this stack there by default.

Run the README commands, type checks including type-tests/model-fields-test.ts, then
Horizon desktop/mobile checks and SQL query-count checks. Verify cookies vs both key
types at HTTP boundaries, primary email confirmation/promotion, private topics, cache
isolation and translations. Fix failures before marking this candidate deployable.
