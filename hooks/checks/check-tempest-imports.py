#!/usr/bin/env python3
"""
Check for proper Tempest imports in test files.

Violations:
- Using requests, urllib, urllib3 directly (should use Tempest clients)
- Missing required decorators import for test methods

OpenStack Tempest Standard:
- Use Tempest service clients for all API calls
- NEVER use raw HTTP libraries (requests, urllib)
- Import decorators for test methods
"""

import ast
import sys


class ImportChecker(ast.NodeVisitor):
    def __init__(self):
        self.violations = []
        self.forbidden_imports = {
            'requests': 'Use Tempest service clients (e.g., self.volumes_client) instead',
            'urllib': 'Use Tempest service clients instead',
            'urllib3': 'Use Tempest service clients instead',
            'httplib': 'Use Tempest service clients instead',
            'http.client': 'Use Tempest service clients instead',
        }
        self.has_decorators_import = False

    def visit_Import(self, node):
        for alias in node.names:
            if alias.name in self.forbidden_imports:
                reason = self.forbidden_imports[alias.name]
                self.violations.append(
                    f"Line {node.lineno}: Forbidden import '{alias.name}' - {reason}"
                )
        self.generic_visit(node)

    def visit_ImportFrom(self, node):
        if node.module:
            base_module = node.module.split('.')[0]
            if base_module in self.forbidden_imports:
                reason = self.forbidden_imports[base_module]
                self.violations.append(
                    f"Line {node.lineno}: Forbidden import from '{node.module}' - {reason}"
                )

            # Check for decorators import
            if 'decorators' in node.module:
                self.has_decorators_import = True

        self.generic_visit(node)


def check_file(filename):
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            content = f.read()
            tree = ast.parse(content, filename=filename)

        checker = ImportChecker()
        checker.visit(tree)

        # Check if file has test methods but no decorators import
        if 'def test_' in content and not checker.has_decorators_import:
            checker.violations.append(
                "Missing required import: from tempest.lib import decorators"
            )

        if checker.violations:
            print(f"\n❌ Import violations in {filename}:")
            for violation in checker.violations:
                print(f"   {violation}")
            print("\n   💡 Fix: Use Tempest service clients for API calls")
            print("   Examples:")
            print("     ✅ volume = self.volumes_client.create_volume(size=1)")
            print("     ❌ response = requests.post(url, json={'size': 1})")
            print("\n   Required import for test methods:")
            print("     from tempest.lib import decorators")
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
        return 0


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: check-tempest-imports.py <test_file.py>")
        sys.exit(1)

    sys.exit(check_file(sys.argv[1]))
