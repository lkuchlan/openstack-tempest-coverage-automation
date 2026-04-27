#!/usr/bin/env python3
import json
import sys

data = json.load(sys.stdin)
fields = data["fields"]

print("=== TICKET INFORMATION ===")
print(f"Key: {data['key']}")
print(f"Type: {fields['issuetype']['name']}")
print(f"Summary: {fields.get('summary', 'N/A')}")
print(f"Status: {fields['status']['name']}")
print(f"Priority: {fields['priority']['name']}")
print(f"Assignee: {fields['assignee']['displayName'] if fields.get('assignee') else 'Unassigned'}")
print(f"Reporter: {fields['reporter']['displayName']}")
print(f"Created: {fields['created']}")
print(f"Fix Version: {fields['fixVersions'][0]['name'] if fields.get('fixVersions') else 'None'}")

components = ', '.join([c['name'] for c in fields.get('components', [])])
print(f"Components: {components if components else 'None'}")

labels = ', '.join(fields.get('labels', []))
print(f"Labels: {labels if labels else 'None'}")
print()

print("=== PARENT EPIC ===")
if fields.get("parent"):
    print(f"Epic Key: {fields['parent']['key']}")
    print(f"Epic Summary: {fields['parent']['fields']['summary']}")
    print(f"Epic Status: {fields['parent']['fields']['status']['name']}")
    print(f"Epic Priority: {fields['parent']['fields']['priority']['name']}")
else:
    print("No parent epic")
print()

print("=== DESCRIPTION ===")
description = fields.get("description")
if description:
    print(description)
else:
    print("No description")
print()

print("=== LINKED ISSUES ===")
issuelinks = fields.get("issuelinks", [])
if issuelinks:
    for link in issuelinks:
        if "outwardIssue" in link:
            issue = link["outwardIssue"]
            link_type = link["type"]["outward"]
            print(f"{link_type}: {issue['key']} - {issue['fields']['summary']} ({issue['fields']['status']['name']})")
        elif "inwardIssue" in link:
            issue = link["inwardIssue"]
            link_type = link["type"]["inward"]
            print(f"{link_type}: {issue['key']} - {issue['fields']['summary']} ({issue['fields']['status']['name']})")
else:
    print("No linked issues")
