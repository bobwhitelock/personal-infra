#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'

# User-defined fields, passed in as env vars when this script is run.
# "password" in the name means these will be treated as sensitive data.
#
# <UDF name="PERSONAL_SSH_PUBLIC_KEY" label="Personal SSH public key, for pushing to Dokku from local machine" />
# <UDF name="REPLACE_NETLIFY_DNS_RECORD_STACKSCRIPT_ID" label="Stackscript ID for libexec/replace_netlify_dns_record.py" />
# <UDF name="GITHUB_TOKEN__PASSWORD" label="GitHub API token" />
# Underscore suffix as "LINODE" namespace is reserved.
# <UDF name="_LINODE_TOKEN__PASSWORD" label="Linode API token" />
# <UDF name="NETLIFY_TOKEN__PASSWORD" label="Netlify API token" />


GITHUB_TOKEN="$GITHUB_TOKEN__PASSWORD"
LINODE_TOKEN="$_LINODE_TOKEN__PASSWORD"
NETLIFY_TOKEN="$NETLIFY_TOKEN__PASSWORD"

WEB_SERVER_PUBLIC_IP="$(ip addr | grep 'inet .* eth0' | xargs | cut -d' ' -f2 | cut -d/ -f1)"

GITHUB_DEPLOY_SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFcvEHeU6AdLHal23FDeBMKj6ru32OaUNR9Gl8Kvz5P3WBMZd16yHjOPGfY0NxrPMhLjlTvPLFbEFDGiLqqZY0kcxvFaSeayFnRdHX9lRTqMRbO2/VTOZIjSCZ4f2slZzZASalplb4GnDfc5M+n4GBQXNtP1q11fn9cfUl2An2YmG6ndXg5ip5CaBqY+Z2QNdxDYt+Cu7jcnsjwYcrNrN5y/UK+k/WjE2Slu7ojaOBHI4Z0f2cWo7S1TEXkz6+Es+aVKby5DTmqEkpjAlafTPOIi5ORYVdYfP3VHXF3omqBbS2U5uJxAlcmKNpGdY9T3ruu24E2KR14JZVQnksYYB1CW4P68s6CcmOfsIqHBu26pihlpoWlKFq0id/4M7T+A3/x7/uH9tyeiirBK2wUSNe/W2mQh9bvKWPczhwdvYIPZmigMEnuJVrFEK0V1e8F07ZFzR9y+uTLwPL9MCoXVAAMnxG7JD6EMIHbiDB5Gc6lOi8bEjfDKwKZ7FtmLJdzjMLYlQBfj1n8qE8euIGlX0O2tlMNq6ydmjoNzpRvnxeLoQIPxzS+jPAKrZOXE8qzD4bvgnxtVT29II8S4YOhN2ur/pBnexXW2EzkpmEAIiq6f0nX0VaAuwEYsbOa/qeKFL81mD8mVBmmsOXhvqyOm+Q0ehLmUrD7ZlQHsRZB+LqSw== bob.whitelock1@gmail.com"


main() {
  set -x

  enable_logging
  setup_dokku

  setup_data_warehouse_app
}


enable_logging() {
  # Log all output from this script.
  local log_file
  log_file=/var/log/web_server_bootstrap.log
  exec > >(tee -a "$log_file")
  exec 2> >(tee -a "$log_file")
}


setup_dokku() {
  wget -NP . https://dokku.com/install/v0.31.2/bootstrap.sh
  sudo DOKKU_TAG=v0.31.2 bash bootstrap.sh

  echo "$PERSONAL_SSH_PUBLIC_KEY" | dokku ssh-keys:add personal
  echo "$GITHUB_DEPLOY_SSH_PUBLIC_KEY" | dokku ssh-keys:add github_deploy
}


setup_data_warehouse_app() {
  # TODO DRY up repeated uses of same hostname, app name, and other stuff in
  # here.
  dokku apps:create data-warehouse
  dokku domains:set data-warehouse data.bobwhitelock.co.uk

  # TODO Change this temporary password.
  # shellcheck disable=SC2016
  dokku config:set data-warehouse DATASETTE_BOB_PASSWORD_HASH='pbkdf2_sha256$480000$03a564f6cd7cf7bbc559802d05491e7e$fcLBSxVR/Oa4Pl/rIG50MjEIu9WsKy+9qm4d7YJBCjE=' --no-restart

  curl \
    -H "Authorization: Bearer $LINODE_TOKEN" \
    "https://api.linode.com/v4/linode/stackscripts/$REPLACE_NETLIFY_DNS_RECORD_STACKSCRIPT_ID" | \
    jq .script --raw-output \
    > replace_netlify_dns_record.py
  chmod +x replace_netlify_dns_record.py
  # TODO needed?
  export NETLIFY_TOKEN
  ./replace_netlify_dns_record.py "{\"type\":\"A\",\"hostname\": \"data.bobwhitelock.co.uk\", \"value\": \"$WEB_SERVER_PUBLIC_IP\", \"ttl\": 60}"

  # Wait for DNS update to propagate.
  # TODO Handle this better than just a magic sleep. Is this needed at all?
  sleep 90

  curl -L \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/bobwhitelock/data-warehouse/actions/workflows/ci_cd.yml/dispatches \
    -d '{"ref": "main"}'

  # Wait for deploy to finish.
  # TODO Handle this better than just a magic sleep, and handle deploy failing.
  sleep 30

  dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
  dokku letsencrypt:set data-warehouse email bob.whitelock1+data-warehouse@gmail.com
  dokku letsencrypt:enable data-warehouse
  dokku letsencrypt:cron-job --add data-warehouse
}


main "$@"
