#!/usr/bin/env python3

import json
import os
import sys

import requests


def main():
    netlify_token = os.environ["NETLIFY_TOKEN"]

    new_record_data = json.loads(sys.argv[1])
    assert new_record_data["type"]
    assert new_record_data["hostname"]
    assert new_record_data["value"]
    hostname = new_record_data["hostname"]

    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": "personal-infra (bob.whitelock1@gmail.com)",
            "Authorization": f"Bearer {netlify_token}",
        }
    )

    dns_zones = session.get("https://api.netlify.com/api/v1/dns_zones").json()

    my_zone_id = next(
        zone for zone in dns_zones if zone["name"] == "bobwhitelock.co.uk"
    )["id"]
    records = session.get(
        f"https://api.netlify.com/api/v1/dns_zones/{my_zone_id}/dns_records"
    ).json()
    current_record = next(
        record for record in records if record["hostname"] == hostname
    )

    session.delete(
        f"https://api.netlify.com/api/v1/dns_zones/{my_zone_id}/dns_records/{current_record['id']}"
    )
    session.post(
        f"https://api.netlify.com/api/v1/dns_zones/{my_zone_id}/dns_records",
        json=new_record_data,
    )

    # TODO same as above
    new_records = session.get(
        f"https://api.netlify.com/api/v1/dns_zones/{my_zone_id}/dns_records"
    ).json()
    new_record = next(
        record for record in new_records if record["hostname"] == hostname
    )
    current_record_fields = set({i for i in current_record.items() if i[0] != "errors"})
    new_record_fields = set({i for i in new_record.items() if i[0] != "errors"})
    changed_fields = dict(current_record_fields ^ new_record_fields).keys()

    _stderr(f"Updated DNS record for {hostname}:")
    for field in changed_fields:
        _stderr(f"  {field}: {current_record[field]} -> {new_record[field]}")


def _stderr(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


if __name__ == "__main__":
    main()
