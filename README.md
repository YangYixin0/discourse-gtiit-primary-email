# GTIIT primary email

Discourse plugin targeting `444e62cc26e96c7da97f08fa45df219f03f60114`
(2026.11.0-latest), Horizon theme. Version 0.1.0 is a development candidate.
Backend tests, Chromium component tests, types and lint passed in isolated CI.
Isolated CNB Horizon page/mobile, email-change and request-isolation acceptance is
recorded in [validation/cnb/README.md](validation/cnb/README.md). Production approval remains outstanding.
See VALIDATION.md for the exact tested commit and run.

## Behavior

Enable `gtiit_primary_email_enabled` explicitly after installation. While enabled,
members cannot opt out. User cards, profiles and post author metadata display
`User#email` (the current primary email). The visible display contains only the
address; its nonvisual accessibility label supports English and Simplified Chinese.
No email is copied into posts, custom fields, or a new table. Reloading/requesting
fresh data after a completed email change updates the display, including old posts.
Previously downloaded pages and copies cannot be recalled.

The plugin adds `gtiit_primary_email` only to user card/profile and post serializers.
A real request and an active, non-staged, non-suspended member (also approved when site approval is required) are required.
API key and User API key requests receive no plugin field. Existing profile and
topic/post visibility rules apply. System users and staged authors are omitted.
Anonymous/background serializers fail closed. No custom API route is introduced.
Core administrator/self email endpoints are unchanged; this plugin does not remove
administrators' existing access to account data. Logged-in members can copy or
collect addresses they are allowed to see.

Primary email associations are bulk preloaded for topic views. Other single-post
responses may load the author's primary email once. No global email cache is used.

## Development and validation

Use a separate Discourse development/test environment at the pinned revision.
Place this repository under its `plugins/discourse-gtiit-primary-email` directory.
Do not execute test commands inside the production container or against production DBs.

```sh
LOAD_PLUGINS=1 bin/rspec plugins/discourse-gtiit-primary-email/spec
bin/qunit plugins/discourse-gtiit-primary-email/test/javascripts
# The workflow invokes upstream linters from the Discourse root.
# bin/lint treats external plugins as standalone packages; see test.yml.
```

Manually verify Horizon desktop/mobile user cards, full profiles, topic pages,
long email wrapping, both languages, two different viewers and logout/login.
Verify primary email changes through the supported confirmation flow, private
category/PM access, deleted/hidden posts and disabled-plugin behavior. Measure SQL
queries on a many-author topic and verify upstream cache headers for authenticated
JSON. Do not enable shared caching of authenticated responses.

## Production change proposal (requires separate approval)

1. Finish automated and browser validation in isolation and review the exact commit.
2. Publish the reviewed plugin Git repository to an agreed remote; back up deployment
   configuration and confirm a recent restorable forum backup.
3. Add the pinned plugin revision to the existing app.yml plugin checkout hook,
   preserving existing hooks. Review the exact diff and scheduled service interruption.
4. Only after explicit approval, rebuild using the existing deployment procedure.
5. Enable the site setting, then check member and anonymous sessions and APIs.

Rollback: disable the setting first (no rebuild required); if necessary remove the
plugin checkout hook and rebuild only with approval. No schema/data rollback is needed.
Disabling cannot revoke addresses already viewed. Do not change SSH/root access.

## Current environment

Current acceptance uses a dedicated CNB workspace at `/workspace/gtiit-validation`
and an isolated Docker development/test container. Dependencies and synthetic
databases were created only there. The Windows project retains the plugin source,
reproduction scripts and evidence. Production remains untouched. See VALIDATION.md
and the CNB report for checks and remaining production work.

## GitHub CI

The private GitHub repository runs `.github/workflows/test.yml` on pushes to main
and pull requests. It checks out the pinned Discourse source on a disposable
GitHub-hosted runner using the upstream test image, then runs this plugin's tests,
type checks and lint. The workflow has read-only repository permissions and uses
synthetic data. There is no production deployment step or production secret.
CI may consume the GitHub account's included Actions quota; review account billing
before enabling paid usage. Runtime dependencies are installed only on the runner.
