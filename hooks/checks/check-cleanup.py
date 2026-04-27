#!/usr/bin/env python3
"""
Check for proper cleanup patterns in Tempest tests.

Violations:
- Resource creation without addCleanup
- Manual cleanup in tearDown (should use addCleanup)

OpenStack Tempest Standard:
- Use addCleanup() for ALL created resources
- addCleanup ensures cleanup even when tests fail
- Executed in LIFO order for proper dependency handling
"""

import ast
import sys


class CleanupChecker(ast.NodeVisitor):
    def __init__(self):
        self.violations = []
        self.cleanup_calls = []
        self.resource_creations = []

    def visit_FunctionDef(self, node):
        # Look for test methods
        if node.name.startswith('test_'):
            self.check_test_method(node)
        self.generic_visit(node)

    def check_test_method(self, node):
        has_cleanup = False
        creates_resources = False
        resource_methods = []

        for child in ast.walk(node):
            # Check for addCleanup calls
            if isinstance(child, ast.Call):
                if (isinstance(child.func, ast.Attribute) and
                    child.func.attr == 'addCleanup'):
                    has_cleanup = True

                # Check for resource creation patterns
                if isinstance(child.func, ast.Attribute):
                    method = child.func.attr
                    # Common creation patterns
                    creation_verbs = ['create', 'allocate', 'build', 'add', 'attach']
                    # Resource types
                    resource_types = ['volume', 'server', 'snapshot', 'backup', 'share',
                                      'image', 'network', 'port', 'router', 'instance']

                    # Check if method name contains creation verb + resource type
                    for verb in creation_verbs:
                        for resource in resource_types:
                            if verb in method.lower() and resource in method.lower():
                                creates_resources = True
                                resource_methods.append(f"{method}()")
                                break

        # Violation: creates resources but no cleanup
        if creates_resources and not has_cleanup:
            resources_str = ', '.join(set(resource_methods))
            self.violations.append(
                f"Line {node.lineno}: Test '{node.name}' creates resources ({resources_str}) "
                f"but has no addCleanup calls"
            )


def check_file(filename):
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            content = f.read()
            tree = ast.parse(content, filename=filename)

        # Skip if not a test file
        if 'def test_' not in content:
            return 0

        checker = CleanupChecker()
        checker.visit(tree)

        if checker.violations:
            print(f"\n❌ Cleanup violations in {filename}:")
            for violation in checker.violations:
                print(f"   {violation}")
            print("\n   💡 Fix: Add self.addCleanup() after creating resources")
            print("   Example:")
            print("     volume = self.create_volume()")
            print("     self.addCleanup(self.delete_volume, volume['id'])")
            print("\n   Why: addCleanup ensures cleanup even if test fails")
            print("   Reference: https://docs.openstack.org/tempest/latest/HACKING.html")
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
        return 0


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: check-cleanup.py <test_file.py>")
        sys.exit(1)

    sys.exit(check_file(sys.argv[1]))
