# CNB acceptance — 2026-11-09

This folder records isolated acceptance using fictional accounts, addresses and posts.
No production server, database, backup, credentials or deployment configuration was used.

## Source and runtime

- Discourse: `444e62cc26e96c7da97f08fa45df219f03f60114` (2026.11.0-latest).
- Source archive SHA-256: `e25172d2855b1d8653adbc98db30f5dafa9b6705a42244d830d055d9661375ea`.
- Plugin baseline: GitHub main `dc31e0b4c4ba2bd6d957732a7f4ceef2f68ceabd`.
- Imported baseline Git tree: `93b35cb08b83a40a181d68835ece8242b26fa60c`, identical to GitHub.
- The only changes between tested `9dd76b2879a04358d670efd7b1f06d9f73625e56`
  and that main were README.md and VALIDATION.md.
- Debian 13 CNB host, 8 visible CPUs, 16 GiB memory limit, no swap.
- Image: `discourse/discourse_test@sha256:7bd0547596f255e1b85c64a0de5f22bc2b38b023beff24371a561a512a147998`.
- Ruby 4.0.9, Bundler 4.0.23, Node 22.23.4, pnpm 12.11.2, PostgreSQL 18.6.
- `fonts-noto-cjk` installed inside the container for complete Chinese glyphs.
- Mailpit: `axllent/mailpit@sha256:aef2aacc11f075ec0fb6874275ee4a421e688e11a96ebb296134d1735c7761ce`.
- Horizon, default theme ID -2, no added theme components.
- HTTP published only on CNB loopback; Mailpit and PostgreSQL are not published.

## Changes found during acceptance

Core post-author CSS applied `white-space: nowrap` and `overflow: hidden` to the
email span. A long mobile address had scrollWidth 481px inside a 278px visible
component. The plugin now gives its post-author span normal wrapping and a full
flex row, with a shrinkable address. No core or Horizon files were changed.

At the owner's request, all three display locations now show the address alone.
The English/Chinese label is nonvisual, on an accessible group.

## Results

- **24 page cases passed**: 1440×1000 desktop and 390×844 mobile emulation × English
  and Simplified Chinese × profile, user card and post author × normal and long
  addresses. Assertions scope the card to `#user-card`, verify address-only text,
  translated accessibility labels, component bounds, scrollWidth and page overflow.
- **93 request/SQL assertions passed** in `http-results.json`. Actual HTTP requests
  alternate Alice, anonymous and Bob sessions over identical profile/card/topic
  paths for three rounds. Member responses include the field; anonymous responses
  omit it. Authenticated responses have `no-store, must-revalidate, private,
  max-age=0`. Secondary addresses are excluded.
- Both valid API-key and read-scoped User-API-key requests return 200 for public
  profile/card/topic JSON without the plugin field. Synthetic keys are created in
  memory, never printed or saved, and deleted after the checks.
- Alice can access the restricted category topic and private message; Bob,
  anonymous users and both Bob API credentials receive 404 for each.
- **11 email-flow assertions passed**: UI change request, confirmation sent to the
  old address, UI old-address confirmation, confirmation sent to the new address,
  UI new-address confirmation. Until both confirmations finish, all three JSON
  locations and the original post retain `alice@example.test`. Fresh requests
  then return `alice.changed@example.test`; the old post, full profile and card
  visibly update. `alice.secondary@example.test` remains excluded. Confirmation
  links are consumed in memory from the local Mailpit API, not persisted.
- **7 session-transition assertions passed**: Bob login, logout, anonymous profile
  and topic DOM, anonymous JSON, and login as Alice in the same browser context.
  No plugin field remains in fresh anonymous responses; Alice sees the updated
  original post after login.
- **Batch SQL**: ActiveSupport SQL instrumentation around `TopicView` loading and
  `PostSerializer` serialization, with a request-aware Guardian and SQL query cache
  disabled, measured 20 posts from 20 authors. Plugin disabled: 0 user_emails
  selects. Enabled: 1 select using `primary = TRUE AND user_id IN (...)`, with
  20 serialized email fields. This is an instrumented application path, not an
  HTTP-server SQL trace; actual topic HTTP output was checked separately.
- Changed-file Prettier, ESLint and Stylelint passed. The upstream `bin/lint --fix`
  external-plugin wrapper was attempted but cannot resolve its standalone
  workspace dependency; upstream tools were invoked from the Discourse root as
  in the existing CI workflow.
- Chromium QUnit: **2 tests, 2 passed, 0 failures**, including address-only text,
  nonvisual labeling, escaping and withholding. `CI=1` selects the upstream
  no-sandbox Chromium option required inside the root-run test container.

Structured results and representative screenshots are in [evidence](evidence/).
The complete 24-case screenshot set is also retained in the local project.

## Reproduce in a disposable CNB environment

Use Windows OpenSSH/SCP. No Codex installation or login inside CNB is needed.
Do not use these scripts on production. They create synthetic users and databases.
They assume `/workspace/gtiit-validation` is exclusively dedicated to this run.

1. Download the pinned Discourse archive from
   `https://codeload.github.com/discourse/discourse/tar.gz/444e62cc26e96c7da97f08fa45df219f03f60114`,
   verify its SHA-256 above, and extract it as `/workspace/gtiit-validation/discourse`.
2. Archive this plugin checkout with prefix `discourse-gtiit-primary-email/` and
   extract it under `discourse/plugins/`. Copy this folder's scripts to
   `/workspace/gtiit-validation/`; create its `logs` directory.
3. Start the pinned test image with name `gtiit-validation`, entrypoint bash,
   command `-lc 'sleep infinity'`, `--shm-size=2g`, bind mount
   `/workspace/gtiit-validation:/workspace`, and loopback-only port mapping
   `127.0.0.1:3000:3000`. Start pinned Mailpit with
   `--network container:gtiit-validation`, without published ports.
4. Install `fonts-noto-cjk` inside the test container, then run
   `bash /workspace/bootstrap.sh`. For Ruby commands
   below use `RAILS_ENV=development LOAD_PLUGINS=1 PGUSER=discourse PGPASSWORD=discourse`
   and working directory `/workspace/discourse`. These are disposable local DB
   fixture values, not production credentials.
5. Run `bin/rails runner /workspace/seed.rb`. It selects Horizon and creates only
   fictional fixtures, including a secondary email, private category and PM.
6. Start `bin/dev` with the same environment and
   `UNICORN_BIND_ALL=1 UNICORN_PORT=3000 UNICORN_WORKERS=2`.
7. Run `bin/rails runner /workspace/http_acceptance.rb` **to completion first**.
   It temporarily toggles the plugin setting for the SQL comparison. Do not run
   page checks concurrently with that setting change.
8. With `PLAYWRIGHT_BROWSERS_PATH=/home/discourse/.cache/ms-playwright`, run
   `node /workspace/browser.cjs`. It uses the full Chromium channel included in
   the image and writes screenshots and `layout-results.json`.
9. Run `bin/rails runner /workspace/reset_email.rb`, then
   `node /workspace/email_flow.cjs` with the browser environment above. The reset
   only affects Alice's synthetic email fixture. It enables delivery solely to
   local Mailpit. Run `node /workspace/sessions.cjs` after email-flow completion.
10. Repeated runs may trigger normal login throttling. The optional
    `clear_login_limits.rb` clears only loopback login counters in this disposable
    environment; it does not change authentication settings.
11. Stop the development frontend before running `targeted_checks.sh`: QUnit and
    the dev watcher share `frontend/discourse/dist`. If an exited watcher leaves
    `dist/manifest/build.json`, preserve/move that stale marker only after verifying
    its recorded process has exited. Do not run builds concurrently.
12. Retain `/workspace/evidence` and the focused test output. Do not export the
    database, Redis, mail contents, server logs containing confirmation URLs,
    browser storage, API keys or any production material.

## Limits and production boundary

Mobile means Chromium device/viewport emulation, not a physical iOS/Android test.
Cache checks cover the isolated application and browser, not a production CDN or
reverse proxy. The instrumented SQL result covers the topic-view/post-serializer
path. The existing backend suite was not rerun because backend code did not change.
This is targeted plugin acceptance, not a complete Discourse regression suite.

No production installation, rebuild, restart, SSH change or deployment occurred.
Production still requires a separate exact installation/backup/rollback proposal
and explicit approval.
