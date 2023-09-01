#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'


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

  # TODO Stop duplicating this here and in `main.tf`.
  echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC3DJvy3N7izwrMsYXlvkO4DGL+1hEv0om6AnJIXUgSGhhKwfFeqKBK3aevqPLA86kS/43uhL2BT35nf3JFdtqg1TcLYzBHDDjpPZBDWIjrQyqvCKUuGL4a698Uu5EZ/MgxBnM8BBA90+Y2qLXhbq6ttSywrzAAIlVXCCaU6i6vWz7XyQhWlb0kOzgjVR7OHI9CJ433Fbdp1QXpZ2iMgRJdP2V2BiYE3LjjoMaF1GqhrKOMHlxJlVXarNh4OmKq3xfv5kKGYjGiZZOpxZmB2kBkSvJdVxMTCED9ume+KqD2cqmbPTx4WA56Ms5nqUl92gT6h730B4PBkMTcgWqcgUzf+JApbWINc0bOwsjTfr6GTI8xoaZGz4kNJ42cepwqzgQ6zfFHoJowVdkp9sMM2xAIGQ4BMnhbOiiAIUdprkJm94qSo+ZBlNcjdwCytpfVJwP4u2f24EZEVU6eGW7ptzdMg5MAvGt3ZIkHhLhbdrVV9JQTwUwkGFbykhXkRhElRNLzdqKox6JwKr+0NjHkILYSOp+GFkt2EyZRDo7nv6TE6Etge6TMi9XFIOsPjQY0eg4HnJHbXkn9Z+LDhgxYsDOR3fym9VCYY7bIX2MuRO0JJ+cy9hK8AwnQynXPJ/85AdSQCAhfIaUebLTmF9mF9DaCI/dnW/wDln3+HfR35pgHhQ== bob.whitelock1@gmail.com"| dokku ssh-keys:add admin
}


setup_data_warehouse_app() {
  dokku apps:create data-warehouse
  dokku domains:set data-warehouse data.bobwhitelock.co.uk

  # TODO Change this temporary password.
  dokku config:set data-warehouse DATASETTE_BOB_PASSWORD_HASH='pbkdf2_sha256$480000$03a564f6cd7cf7bbc559802d05491e7e$fcLBSxVR/Oa4Pl/rIG50MjEIu9WsKy+9qm4d7YJBCjE=' --no-restart

  # TODO I don't think this fully works as the app isn't running yet, need a
  # placeholder app or to run this after first push or something.
  dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
  dokku letsencrypt:set data-warehouse email bob.whitelock1+data-warehouse@gmail.com
  dokku letsencrypt:enable data-warehouse
  dokku letsencrypt:cron-job --add data-warehouse

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
