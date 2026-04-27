#!/usr/bin/env python3
import json
import sys

data = json.load(sys.stdin)
issues = data.get("issues", [])
total = len(issues)
print(f"Child issues of Epic OSPRH-22614 (Total: {total}):")
print()

if total == 0:
    print("  No child issues found")
else:
    for issue in issues:
        key = issue["key"]
        summary = issue["fields"]["summary"]
        issuetype = issue["fields"]["issuetype"]["name"]
        status = issue["fields"]["status"]["name"]
        priority = issue["fields"]["priority"]["name"]
        print(f"  {key} ({issuetype}) - {summary}")
        print(f"    Status: {status}, Priority: {priority}")
        print()
