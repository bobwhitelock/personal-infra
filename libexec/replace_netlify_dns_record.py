#!/usr/bin/env python3

from collections import defaultdict
import json
import os
import sys

import requests


NETLIFY_TOKEN = os.environ["NETLIFY_TOKEN"]

SESSION = requests.Session()
SESSION.headers.update(
    {
        "User-Agent": "personal-infra (bob.whitelock1@gmail.com)",
        "Authorization": f"Bearer {NETLIFY_TOKEN}",
    }
)


def main():
    new_record_data = _load_record_data(sys.argv[1])
    hostname = new_record_data["hostname"]

    my_zone_id = _find_zone_id_for_domain("bobwhitelock.co.uk")
    current_record = _find_dns_record(zone_id=my_zone_id, hostname=hostname)
    new_record = _replace_dns_record(
        zone_id=my_zone_id, record_id=current_record["id"], record_data=new_record_data
    )

    _stderr(f"Updated DNS record for {hostname}:")
    _report_changed_fields(old=current_record, new=new_record)


def _load_record_data(arg: str):
    record_data = json.loads(arg)
    assert record_data["type"]
    assert record_data["hostname"]
    assert record_data["value"]
    return record_data


def _find_zone_id_for_domain(domain: str) -> str:
    dns_zones = _netlify_api_request("dns_zones")
    return next(zone for zone in dns_zones if zone["name"] == domain)["id"]


def _find_dns_record(*, zone_id: str, hostname: str) -> dict:
    records = _netlify_api_request(f"dns_zones/{zone_id}/dns_records")
    try:
        return next(record for record in records if record["hostname"] == hostname)
    except:
        # If no record exists for this hostname already, treat every field as
        # empty (will only matter for reporting changed fields).
        return defaultdict(lambda: None)


def _replace_dns_record(*, zone_id: str, record_id: str, record_data: dict) -> dict:
    _netlify_api_request(f"dns_zones/{zone_id}/dns_records/{record_id}", "DELETE")
    return _netlify_api_request(
        f"dns_zones/{zone_id}/dns_records",
        "POST",
        json=record_data,
    )


def _netlify_api_request(endpoint: str, method: str = "GET", **requests_kwargs):
    response = SESSION.request(
        method, f"https://api.netlify.com/api/v1/{endpoint}", **requests_kwargs
    )
    try:
        return response.json()
    except:
        return response


def _report_changed_fields(*, old: dict, new: dict):
    old_fields = set({i for i in old.items() if i[0] != "errors"})
    new_fields = set({i for i in new.items() if i[0] != "errors"})
    changed_fields = dict(old_fields ^ new_fields).keys()
    for field in changed_fields:
        _stderr(f"  {field}: {old[field]} -> {new[field]}")


def _stderr(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


if __name__ == "__main__":
    main()
