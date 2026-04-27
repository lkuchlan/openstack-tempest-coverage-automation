# Copyright {YEAR} Red Hat, Inc.
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

"""
Template for Tempest API Tests

Replace placeholders:
- {SERVICE} - Service name (e.g., Cinder, Manila)
- {FEATURE} - Feature being tested (e.g., Volume Multiattach)
- {BASE_CLASS} - Base test class (e.g., BaseVolumeTest)
- {CLIENT_NAME} - Client attribute (e.g., volumes_client)
- {RESOURCE_TYPE} - Resource type (e.g., volume, share)
"""

from tempest import config
from tempest.lib.common.utils import data_utils
from tempest.lib import decorators

# Import appropriate base class
from {plugin_package}.tests.api import base

CONF = config.CONF


class {Feature}Test(base.{BaseClass}):
    """Test {feature} functionality."""

    @classmethod
    def skip_checks(cls):
        """Skip tests if requirements not met."""
        super({Feature}Test, cls).skip_checks()
        # Add any feature-specific skip conditions
        # Example:
        # if not CONF.{service}_feature_enabled.{feature}:
        #     raise cls.skipException("{Feature} is disabled")

    @classmethod
    def resource_setup(cls):
        """Set up resources for all tests in this class."""
        super({Feature}Test, cls).resource_setup()
        # Create any shared resources needed for all tests
        # Example:
        # cls.{resource} = cls.create_{resource}()

    @decorators.idempotent_id('{UUID-GENERATE-NEW}')
    @decorators.attr(type='smoke')
    def test_{operation}_positive(self):
        """Test {operation} with valid inputs.

        1. Create {resource}
        2. Perform {operation}
        3. Verify expected result
        4. Cleanup (automatic via addCleanup)
        """
        # Create resource
        {resource}_name = data_utils.rand_name(
            self.__class__.__name__ + '-{resource}')

        {resource} = self.{client_name}.create_{resource}(
            name={resource}_name
        )['{resource}']

        # Add cleanup
        self.addCleanup(
            self.delete_{resource},
            {resource}['id']
        )

        # Wait for resource to be ready (use waiter, not sleep!)
        waiters.wait_for_{resource}_resource_status(
            self.{client_name},
            {resource}['id'],
            'available'
        )

        # Perform operation
        result = self.{client_name}.{operation}(
            {resource}['id'],
            # Add operation-specific parameters
        )

        # Verify expected behavior
        self.assertEqual(expected_value, result['{field}'])
        self.assertIn(expected_status, result['status'])

    @decorators.idempotent_id('{UUID-GENERATE-NEW}')
    @decorators.attr(type='negative')
    def test_{operation}_negative_unauthorized(self):
        """Test {operation} fails with unauthorized user.

        Negative tests verify proper error handling.
        """
        # Create resource as admin
        {resource} = self.{client_name}.create_{resource}()['{resource}']
        self.addCleanup(self.delete_{resource}, {resource}['id'])

        # Attempt operation that should fail
        self.assertRaises(
            lib_exc.Forbidden,  # or Unauthorized, NotFound, etc.
            self.{client_name}.{operation},
            {resource}['id']
        )

    @decorators.idempotent_id('{UUID-GENERATE-NEW}')
    @decorators.attr(type='api')
    def test_{operation}_with_{condition}(self):
        """Test {operation} with specific condition.

        Test edge cases and specific scenarios.
        """
        # Test implementation
        pass


class {Feature}AdminTest(base.{BaseAdminClass}):
    """Test {feature} admin-only functionality."""

    credentials = ['admin']

    @decorators.idempotent_id('{UUID-GENERATE-NEW}')
    @decorators.attr(type='smoke')
    def test_{admin_operation}(self):
        """Test admin-only operation."""
        # Test implementation
        pass


# RBAC Tests (if applicable)
class {Feature}RbacTest(base.{BaseRbacClass}):
    """Test {feature} RBAC policies."""

    credentials = ['primary', 'admin', 'alt']

    @decorators.idempotent_id('{UUID-GENERATE-NEW}')
    @decorators.attr(type='rbac')
    def test_{operation}_rbac_admin(self):
        """Test operation is authorized for admin role."""
        pass

    @decorators.idempotent_id('{UUID-GENERATE-NEW}')
    @decorators.attr(type='rbac')
    def test_{operation}_rbac_member(self):
        """Test operation is authorized for member role."""
        pass

    @decorators.idempotent_id('{UUID-GENERATE-NEW}')
    @decorators.attr(type='rbac')
    def test_{operation}_rbac_reader_negative(self):
        """Test operation is denied for reader role."""
        pass
