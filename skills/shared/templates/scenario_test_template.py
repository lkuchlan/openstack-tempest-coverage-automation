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
Template for Tempest Scenario Tests

Scenario tests combine multiple operations to test real-world workflows.

Replace placeholders:
- {SERVICE} - Service name
- {SCENARIO} - Scenario description
- {BASE_CLASS} - Base scenario test class
"""

from tempest import config
from tempest.lib.common.utils import data_utils
from tempest.lib import decorators

from {plugin_package}.tests.scenario import manager

CONF = config.CONF


class {Scenario}ScenarioTest(manager.{ScenarioBaseClass}):
    """Test {scenario} end-to-end workflow."""

    @classmethod
    def skip_checks(cls):
        """Skip if scenario requirements not met."""
        super({Scenario}ScenarioTest, cls).skip_checks()
        # Check for required features/services
        # Example:
        # if not CONF.service_available.{service}:
        #     raise cls.skipException("{Service} is not available")

    @classmethod
    def setup_credentials(cls):
        """Set up credentials needed for scenario."""
        super({Scenario}ScenarioTest, cls).setup_credentials()
        # Scenario tests often need multiple credentials
        # cls.set_network_resources() if needed

    @classmethod
    def resource_setup(cls):
        """Set up resources for scenario tests."""
        super({Scenario}ScenarioTest, cls).resource_setup()
        # Create long-lived resources for scenario

    @decorators.idempotent_id('{UUID-GENERATE-NEW}')
    @decorators.attr(type='slow')
    def test_{scenario}_workflow(self):
        """Test complete {scenario} workflow.

        Scenario:
        1. Step 1: Create initial resources
        2. Step 2: Perform operation A
        3. Step 3: Verify intermediate state
        4. Step 4: Perform operation B
        5. Step 5: Verify final state
        6. Cleanup (automatic)
        """
        # Step 1: Create resources
        # Use helper methods for clarity
        resource_a = self._create_resource_a()
        resource_b = self._create_resource_b()

        # Step 2: Perform workflow operations
        self._perform_operation_a(resource_a, resource_b)

        # Step 3: Verify intermediate state
        self._verify_intermediate_state(resource_a)

        # Step 4: Continue workflow
        self._perform_operation_b(resource_a)

        # Step 5: Verify final state
        self._verify_final_state(resource_a, resource_b)

        # Cleanup happens automatically via addCleanup

    # Helper methods for scenario steps
    def _create_resource_a(self):
        """Helper: Create resource A for scenario."""
        name = data_utils.rand_name(self.__class__.__name__ + '-resource-a')

        resource = self.{client_name}.create_{resource}(
            name=name,
            # Add required parameters
        )['{resource}']

        self.addCleanup(self.delete_{resource}, resource['id'])

        # Wait for ready state
        waiters.wait_for_{resource}_resource_status(
            self.{client_name},
            resource['id'],
            'available'
        )

        return resource

    def _create_resource_b(self):
        """Helper: Create resource B for scenario."""
        # Similar pattern to _create_resource_a
        pass

    def _perform_operation_a(self, resource_a, resource_b):
        """Helper: Perform operation A in workflow."""
        result = self.{client_name}.{operation_a}(
            resource_a['id'],
            resource_b['id']
        )

        # Wait for operation to complete
        waiters.wait_for_{operation}_completion(
            self.{client_name},
            result['id']
        )

        return result

    def _verify_intermediate_state(self, resource):
        """Helper: Verify state after operation A."""
        # Get current state
        current = self.{client_name}.show_{resource}(
            resource['id']
        )['{resource}']

        # Assert expected state
        self.assertEqual('expected_status', current['status'])
        self.assertIsNotNone(current['field'])

    def _perform_operation_b(self, resource):
        """Helper: Perform operation B in workflow."""
        pass

    def _verify_final_state(self, resource_a, resource_b):
        """Helper: Verify final workflow state."""
        pass

    @decorators.idempotent_id('{UUID-GENERATE-NEW}')
    @decorators.attr(type='slow')
    def test_{scenario}_workflow_with_failure(self):
        """Test {scenario} workflow handles failures gracefully.

        This tests error handling in the scenario.
        """
        # Create resources
        resource = self._create_resource_a()

        # Induce failure condition
        self._induce_failure_condition(resource)

        # Verify graceful handling
        self._verify_error_handling(resource)

    def _induce_failure_condition(self, resource):
        """Helper: Create condition that should trigger error."""
        pass

    def _verify_error_handling(self, resource):
        """Helper: Verify system handles error correctly."""
        pass


class {Scenario}NegativeScenarioTest(manager.{ScenarioBaseClass}):
    """Test negative scenarios for {scenario}."""

    @decorators.idempotent_id('{UUID-GENERATE-NEW}')
    @decorators.attr(type='slow')
    def test_{scenario}_invalid_state_transition(self):
        """Test scenario fails on invalid state transition."""
        # Test invalid workflow paths
        pass
