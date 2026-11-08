#!/usr/bin/env bash
set -euo pipefail
cd /workspace/discourse
git init
git add -f plugins/*/plugin.rb
git -c user.name='Synthetic Validation' -c user.email='validation@example.test' commit -m 'Record bundled plugin manifest for isolated archive checks' || true
bin/lint --fix plugins/discourse-gtiit-primary-email/assets/javascripts/discourse/components/gtiit-primary-email.gjs plugins/discourse-gtiit-primary-email/test/javascripts/integration/components/gtiit-primary-email-test.gjs plugins/discourse-gtiit-primary-email/assets/stylesheets/common/gtiit-primary-email.scss || lint_wrapper_status=$?
echo "LINT_WRAPPER_STATUS=${lint_wrapper_status:-0}"
pnpm exec prettier --write plugins/discourse-gtiit-primary-email/assets/javascripts/discourse/components/gtiit-primary-email.gjs plugins/discourse-gtiit-primary-email/test/javascripts/integration/components/gtiit-primary-email-test.gjs plugins/discourse-gtiit-primary-email/assets/stylesheets/common/gtiit-primary-email.scss
pnpm exec eslint plugins/discourse-gtiit-primary-email/assets/javascripts/discourse/components/gtiit-primary-email.gjs plugins/discourse-gtiit-primary-email/test/javascripts/integration/components/gtiit-primary-email-test.gjs
pnpm exec stylelint plugins/discourse-gtiit-primary-email/assets/stylesheets/common/gtiit-primary-email.scss
export RAILS_ENV=test LOAD_PLUGINS=1 PGUSER=discourse PGPASSWORD=discourse
export CI=1 QUNIT_PARALLEL=1 DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null PLAYWRIGHT_BROWSERS_PATH=/home/discourse/.cache/ms-playwright
bin/rake db:create db:migrate
bin/qunit --standalone --target discourse-gtiit-primary-email
echo TARGETED_CHECKS_COMPLETE
