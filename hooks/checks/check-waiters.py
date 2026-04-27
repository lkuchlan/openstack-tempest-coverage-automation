#!/usr/bin/env python3
"""
Check for proper waiter usage in Tempest tests.

Violations:
- Using time.sleep() instead of waiters
- Using direct polling loops instead of waiters

OpenStack Tempest Standard:
- Use waiters.wait_for_*_status() for resource state changes
- NEVER use time.sleep() for polling
- Waiters provide proper timeout handling and exponential backoff
"""

import ast
import sys


class WaiterChecker(ast.NodeVisitor):
    def __init__(self):
        self.violations = []
        self.line_numbers = []

    def visit_Call(self, node):
        # Check for time.sleep()
        if isinstance(node.func, ast.Attribute):
            if (isinstance(node.func.value, ast.Name) and
                node.func.value.id == 'time' and
                node.func.attr == 'sleep'):
                self.violations.append(
                    f"Line {node.lineno}: Using time.sleep() - Use Tempest waiters instead"
                )
                self.line_numbers.append(node.lineno)

        # Check for sleep() without time module (from time import sleep)
        if isinstance(node.func, ast.Name) and node.func.id == 'sleep':
            self.violations.append(
                f"Line {node.lineno}: Using sleep() - Use Tempest waiters instead"
            )
            self.line_numbers.append(node.lineno)

        self.generic_visit(node)

    def visit_While(self, node):
        # Check for manual polling loops (common anti-pattern)
        # while resource['status'] != 'available': ...
        # This is a heuristic - may have false positives
        if isinstance(node.test, ast.Compare):
            # Check if comparing something that looks like a status
            try:
                # Try to detect status-like comparisons
                if any(name in ast.unparse(node.test).lower()
                       for name in ['status', 'state', 'available', 'active', 'error']):
                    self.violations.append(
                        f"Line {node.lineno}: Manual polling loop detected - Consider using Tempest waiters"
                    )
                    self.line_numbers.append(node.lineno)
            except:
                pass  # Skip if can't unparse

        self.generic_visit(node)


def check_file(filename):
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            content = f.read()
            tree = ast.parse(content, filename=filename)

        checker = WaiterChecker()
        checker.visit(tree)

        if checker.violations:
            print(f"\n❌ Waiter violations in {filename}:")
            for violation in checker.violations:
                print(f"   {violation}")
            print("\n   💡 Fix: Use Tempest waiters instead of sleep/polling")
            print("   Examples:")
            print("     waiters.wait_for_volume_resource_status(client, vol_id, 'available')")
            print("     waiters.wait_for_server_status(client, server_id, 'ACTIVE')")
            print("     waiters.wait_for_image_status(client, image_id, 'active')")
            print("\n   Reference: https://docs.openstack.org/tempest/latest/HACKING.html")
            return 1

        return 0

    except SyntaxError as e:
        print(f"❌ Syntax error in {filename}: {e}")
        return 1
    except FileNotFoundError:
        print(f"❌ File not found: {filename}")
        return 1
    except Exception as e:
        print(f"⚠️  Warning: Could not check {filename}: {e}")
        return 0  # Don't block commit on checker errors


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: check-waiters.py <test_file.py>")
        sys.exit(1)

    sys.exit(check_file(sys.argv[1]))
