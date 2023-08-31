#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'


main() {
  set -x

  local log_file

  # Log all output from this script.
  log_file=/var/log/web_server_bootstrap.log
  exec > >(tee -a "$log_file")
  exec 2> >(tee -a "$log_file")

  # Install Dokku.
  wget -NP . https://dokku.com/install/v0.31.2/bootstrap.sh
  sudo DOKKU_TAG=v0.31.2 bash bootstrap.sh
}


main "$@"
