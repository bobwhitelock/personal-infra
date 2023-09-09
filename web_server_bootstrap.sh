#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'

# User-defined fields, passed in as env vars when this script is run.
# "password" in the name means these will be treated as sensitive data.
#
# <UDF name="PERSONAL_SSH_PUBLIC_KEY" label="Personal SSH public key, for pushing to Dokku from local machine" />
# <UDF name="REPLACE_NETLIFY_DNS_RECORD_STACKSCRIPT_ID" label="Stackscript ID for libexec/replace_netlify_dns_record.py" />
# <UDF name="LOG_FILE" label="Log file for this script" />
# <UDF name="GITHUB_TOKEN__PASSWORD" label="GitHub API token" />
# Underscore suffix as "LINODE" namespace is reserved.
# <UDF name="_LINODE_TOKEN__PASSWORD" label="Linode API token" />
# <UDF name="NETLIFY_TOKEN__PASSWORD" label="Netlify API token" />
# <UDF name="DATASETTE_BOB_PASSWORD_HASH" label="Password hash for my data-warehouse user" />


GITHUB_TOKEN="$GITHUB_TOKEN__PASSWORD"
LINODE_TOKEN="$_LINODE_TOKEN__PASSWORD"
NETLIFY_TOKEN="$NETLIFY_TOKEN__PASSWORD"

WEB_SERVER_PUBLIC_IP="$(ip addr | grep 'inet .* eth0' | xargs | cut -d' ' -f2 | cut -d/ -f1)"

GITHUB_DEPLOY_SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFcvEHeU6AdLHal23FDeBMKj6ru32OaUNR9Gl8Kvz5P3WBMZd16yHjOPGfY0NxrPMhLjlTvPLFbEFDGiLqqZY0kcxvFaSeayFnRdHX9lRTqMRbO2/VTOZIjSCZ4f2slZzZASalplb4GnDfc5M+n4GBQXNtP1q11fn9cfUl2An2YmG6ndXg5ip5CaBqY+Z2QNdxDYt+Cu7jcnsjwYcrNrN5y/UK+k/WjE2Slu7ojaOBHI4Z0f2cWo7S1TEXkz6+Es+aVKby5DTmqEkpjAlafTPOIi5ORYVdYfP3VHXF3omqBbS2U5uJxAlcmKNpGdY9T3ruu24E2KR14JZVQnksYYB1CW4P68s6CcmOfsIqHBu26pihlpoWlKFq0id/4M7T+A3/x7/uH9tyeiirBK2wUSNe/W2mQh9bvKWPczhwdvYIPZmigMEnuJVrFEK0V1e8F07ZFzR9y+uTLwPL9MCoXVAAMnxG7JD6EMIHbiDB5Gc6lOi8bEjfDKwKZ7FtmLJdzjMLYlQBfj1n8qE8euIGlX0O2tlMNq6ydmjoNzpRvnxeLoQIPxzS+jPAKrZOXE8qzD4bvgnxtVT29II8S4YOhN2ur/pBnexXW2EzkpmEAIiq6f0nX0VaAuwEYsbOa/qeKFL81mD8mVBmmsOXhvqyOm+Q0ehLmUrD7ZlQHsRZB+LqSw== bob.whitelock1@gmail.com"


main() {
  set -x

  enable_logging
  update_system
  setup_dokku

  setup_data_warehouse_app

  reboot -h now
}


enable_logging() {
  # Log all output from this script.
  exec > >(tee -a "$LOG_FILE")
  exec 2> >(tee -a "$LOG_FILE")
}


update_system() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get upgrade -y
  apt-get autoremove
  apt-get autoclean
}


setup_dokku() {
  wget -NP . https://dokku.com/install/v0.31.2/bootstrap.sh
  bash bootstrap.sh

  echo "$PERSONAL_SSH_PUBLIC_KEY" | dokku ssh-keys:add personal
  echo "$GITHUB_DEPLOY_SSH_PUBLIC_KEY" | dokku ssh-keys:add github_deploy

  # Needed so getting buildpacks from GitHub works.
  ssh-keyscan -H github.com >> ~dokku/.ssh/known_hosts
}


setup_data_warehouse_app() {
  local app_name hostname placeholder_hostname replace_dns_record
  app_name=data-warehouse
  hostname=data.bobwhitelock.co.uk
  placeholder_hostname="placeholder-$(openssl rand -hex 5).bobwhitelock.co.uk"
  replace_dns_record=replace_netlify_dns_record.py

  dokku apps:create "$app_name"
  dokku domains:set "$app_name" "$hostname"
  dokku domains:add "$app_name" "$placeholder_hostname"

  dokku buildpacks:set data-warehouse https://github.com/moneymeets/python-poetry-buildpack.git
  dokku buildpacks:add data-warehouse heroku/python

  dokku config:set "$app_name" \
    DATASETTE_BOB_PASSWORD_HASH="$DATASETTE_BOB_PASSWORD_HASH" \
    --no-restart

  curl \
    -H "Authorization: Bearer $LINODE_TOKEN" \
    "https://api.linode.com/v4/linode/stackscripts/$REPLACE_NETLIFY_DNS_RECORD_STACKSCRIPT_ID" | \
    jq .script --raw-output \
    > "$replace_dns_record"
  chmod +x "$replace_dns_record"
  # TODO needed?
  export NETLIFY_TOKEN
  "./$replace_dns_record" "{\"type\":\"A\",\"hostname\": \"$hostname\", \"value\": \"$WEB_SERVER_PUBLIC_IP\", \"ttl\": 60}"
  # TODO This will clog up my DNS with a new junk placeholder record on every
  # build - need to remove the old ones.
  "./$replace_dns_record" "{\"type\":\"A\",\"hostname\": \"$placeholder_hostname\", \"value\": \"$WEB_SERVER_PUBLIC_IP\", \"ttl\": 60}"

  # Wait for DNS update to propagate.
  # TODO Handle this better than just a magic sleep. Is this needed at all?
  sleep 90

  curl -L \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/bobwhitelock/$app_name/actions/workflows/ci_cd.yml/dispatches" \
    -d '{"ref": "main"}'

  # Wait for deploy to finish.
  # TODO Handle this better than just a magic sleep, and handle deploy failing.
  sleep 30

  dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
  dokku letsencrypt:set "$app_name" email "bob.whitelock1+$app_name@gmail.com"
  dokku letsencrypt:enable "$app_name"
  dokku letsencrypt:cron-job --add "$app_name"
}


main "$@"
