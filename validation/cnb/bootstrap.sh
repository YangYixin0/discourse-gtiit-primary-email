#!/usr/bin/env bash
set -euo pipefail
cd /workspace/discourse
export RAILS_ENV=development LOAD_PLUGINS=1
export PGUSER=discourse PGPASSWORD=discourse
redis-server /etc/redis/redis.conf --daemonize yes --logfile ""
chown -R postgres /var/run/postgresql
sudo -E -u postgres script/start_test_db.rb
sudo -u postgres psql -c "CREATE ROLE discourse LOGIN SUPERUSER PASSWORD 'discourse';"
ln -s /var/www/discourse/vendor/bundle vendor/bundle
bundle config --local path vendor/bundle
bundle config --local deployment true
bundle install --jobs 4
ruby -ryaml -e 'p="pnpm-workspace.yaml"; y=YAML.load_file(p); y["packages"] << "plugins/discourse-gtiit-primary-email"; File.write(p, y.to_yaml)'
pnpm install --no-frozen-lockfile
bin/rake db:create db:migrate
bin/rake assets:precompile:asset_processor assets:precompile:pretty_text
echo BOOTSTRAP_COMPLETE
