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

  # TODO Once bootstrapped, do something like this to update DNS:
  #
  # Find DNS zone ID:
  # $ curl -H "User-Agent: personal-infra (bob.whitelock1@gmail.com)" -H "Authorization: Bearer $NETLIFY_TOKEN" https://api.netlify.com/api/v1/dns_zones | jq .
  #
  # Find bobwhitelock.co.uk zone and then view records:
  # $ curl -H "User-Agent: personal-infra (bob.whitelock1@gmail.com)" -H "Authorization: Bearer $NETLIFY_TOKEN" https://api.netlify.com/api/v1/dns_zones/59736a186f4c5015cc28e7af/dns_records | jq .
  #
  # Delete the old record:
  # $ curl -H "User-Agent: personal-infra (bob.whitelock1@gmail.com)" -H "Authorization: Bearer $NETLIFY_TOKEN" -X DELETE https://api.netlify.com/api/v1/dns_zones/59736a186f4c5015cc28e7af/dns_records/604aa7945e906808f7b3cb8d
  #
  # Create new record:
  # $ curl -H "User-Agent: personal-infra (bob.whitelock1@gmail.com)" -H "Authorization: Bearer $NETLIFY_TOKEN" -H 'Content-Type: application/json' -X POST -d '{"type":"A","hostname": "data.bobwhitelock.co.uk", "value": "178.79.184.237", "ttl": 60}' https://api.netlify.com/api/v1/dns_zones/59736a186f4c5015cc28e7af/dns_records
  #
  # And message somewhere to indicate bootstrapping complete?
  #
  # Also see API docs at https://open-api.netlify.com/#tag/dnsZone
  # Note: no decent Netlify Terraform provider exists, so using API directly
  # seems best.
}


main "$@"
