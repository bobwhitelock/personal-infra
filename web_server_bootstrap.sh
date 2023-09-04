#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'

# User-defined fields, passed in as env vars when this script is run.
#
# <UDF name="PERSONAL_SSH_PUBLIC_KEY" label="Personal SSH public key, for pushing to Dokku from local machine" />


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
}


setup_data_warehouse_app() {
  dokku apps:create data-warehouse
  dokku domains:set data-warehouse data.bobwhitelock.co.uk

  # TODO Change this temporary password.
  # shellcheck disable=SC2016
  dokku config:set data-warehouse DATASETTE_BOB_PASSWORD_HASH='pbkdf2_sha256$480000$03a564f6cd7cf7bbc559802d05491e7e$fcLBSxVR/Oa4Pl/rIG50MjEIu9WsKy+9qm4d7YJBCjE=' --no-restart

  # TODO This doesn't work as the app isn't running yet, need a placeholder app
  # or to run this after first push or something.
  dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
  # dokku letsencrypt:set data-warehouse email bob.whitelock1+data-warehouse@gmail.com
  # dokku letsencrypt:enable data-warehouse
  # dokku letsencrypt:cron-job --add data-warehouse

  # Also need to run libexec/replace_netlify_dns_record.py.
}


main "$@"
