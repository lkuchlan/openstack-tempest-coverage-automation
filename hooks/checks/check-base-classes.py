#!/usr/bin/env python3
"""
Check for proper base class usage in Tempest tests.

Violations:
- Using unittest.TestCase directly (should use Tempest base classes)
- Custom base classes (should use plugin/tempest base classes)

OpenStack Tempest Standard:
- Inherit from proper Tempest base classes
- Service-specific: BaseVolumeTest, BaseSharesTest, BaseImageTest, etc.
- Generic: BaseTestCase, ScenarioTest
- NEVER inherit from unittest.TestCase
"""

import ast
import sys


class BaseClassChecker(ast.NodeVisitor):
    def __init__(self):
        self.violations = []
        # Valid Tempest base class patterns
        self.valid_base_patterns = [
            'BaseVolumeTest', 'BaseSharesTest', 'BaseImageTest',
            'BaseComputeTest', 'BaseNetworkTest', 'BaseTestCase',
            'BaseAdminTest', 'BaseRbacTest', 'ScenarioTest',
            'BaseV2ComputeTest', 'BaseV2ComputeAdminTest',
            'BaseBackupsTest', 'BaseSnapshotsTest',
            'BaseSharesAdminTest', 'BaseSharesMigrationTest',
            'BaseImageAdminTest', 'BaseImageMemberTest',
        ]

    def visit_ClassDef(self, node):
        # Check test classes
        if 'Test' in node.name:
            for base in node.bases:
                base_name = self.get_base_name(base)

                # Check for unittest.TestCase
                if base_name == 'TestCase':
                    self.violations.append(
                        f"Line {node.lineno}: Class '{node.name}' inherits from TestCase - "
                        f"Use Tempest base classes instead"
                    )

                # Check if using valid Tempest base class patterns
                # This is informational - we check for known bad patterns
                if base_name and not any(pattern in base_name for pattern in self.valid_base_patterns):
                    # Check if it's a known bad pattern
                    if base_name in ['object', 'type', 'ABC']:
                        self.violations.append(
                            f"Line {node.lineno}: Class '{node.name}' inherits from '{base_name}' - "
                            f"Use proper Tempest base class"
                        )

        self.generic_visit(node)

    def get_base_name(self, node):
        """Extract base class name from AST node."""
        if isinstance(node, ast.Name):
            return node.id
        elif isinstance(node, ast.Attribute):
            return node.attr
        return None


def check_file(filename):
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            content = f.read()
            tree = ast.parse(content, filename=filename)

        checker = BaseClassChecker()
        checker.visit(tree)

        if checker.violations:
            print(f"\n❌ Base class violations in {filename}:")
            for violation in checker.violations:
                print(f"   {violation}")
            print("\n   💡 Fix: Inherit from proper Tempest base class")
            print("   Examples:")
            print("     ✅ class VolumeTest(BaseVolumeTest):")
            print("     ✅ class ShareTest(BaseSharesTest):")
            print("     ✅ class ScenarioTest(scenario.ScenarioTest):")
            print("     ❌ class MyTest(unittest.TestCase):")
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
        print("Usage: check-base-classes.py <test_file.py>")
        sys.exit(1)

    sys.exit(check_file(sys.argv[1]))
