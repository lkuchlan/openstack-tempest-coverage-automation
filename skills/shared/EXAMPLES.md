# Tempest Coverage Skill - Examples

This file contains real-world examples of using the tempest-coverage skill.

## Example 1: Basic Volume Test Coverage

### Jira Ticket
```
RHEL-12345: Add test coverage for volume backup creation

Requirements:
- Test creating backup from available volume
- Test creating incremental backup
- Test backup with metadata
```

### Invocation
```
/tempest-coverage RHEL-12345
```

### Expected Output
```markdown
# Tempest Coverage Analysis: RHEL-12345

## Summary
- **Service:** Cinder
- **Feature:** Volume backup creation
- **Coverage Status:** ⚠️ Partial

## Existing Coverage
- **File:** cinder_tempest_plugin/api/volume/test_volumes_backup.py
- **Class:** VolumesBackupsTest
- **Methods:**
  - test_volume_backup_create_get_detailed_list_restore_delete()

## Coverage Gaps
1. ❌ Missing: Test for incremental backup creation
2. ❌ Missing: Test for backup with metadata

## Implementation

### File Created
`cinder_tempest_plugin/api/volume/test_volumes_backup.py` (modified)

### Tests Added
1. `test_backup_create_incremental()`
2. `test_backup_create_with_metadata()`

### Code
[Full implementation shown...]

## Validation
- ✅ pep8: PASSED
- ✅ py3: PASSED

## Git Branch
- Branch: tempest-coverage-rhel-12345
- Commit: "Add incremental and metadata backup tests"
```

---

## Example 2: RBAC Test Coverage

### Jira Ticket
```
RHEL-54321: Implement RBAC tests for Manila share revert

Requirements:
- Admin should be able to revert share to snapshot
- Member should be able to revert own share
- Reader should NOT be able to revert
- Negative test for reverting non-existent snapshot
```

### Invocation
```
User: "Please implement RBAC test coverage for Manila share revert to snapshot feature per RHEL-54321"
```

### Expected Workflow

1. **Discovery Phase**
```
Searching for existing patterns...
✓ Found: manila_tempest_plugin/api/base.py
  - BaseSharesRbacTest
✓ Found: manila_tempest_plugin/api/test_shares_actions.py
  - SharesActionsTest.test_revert_to_snapshot()
✓ Pattern identified: Use BaseSharesRbacTest, shares_v2_client
```

2. **Gap Analysis**
```
Existing coverage:
- ✓ Basic revert test exists (non-RBAC)

Missing coverage:
- ❌ RBAC test for admin role
- ❌ RBAC test for member role
- ❌ RBAC test for reader role (negative)
- ❌ Negative test for non-existent snapshot
```

3. **Implementation**
```
Creating new file:
manila_tempest_plugin/api/test_share_revert_rbac.py

Implementing 4 tests following BaseSharesRbacTest pattern...
```

4. **Validation**
```
Running: tox -e pep8
✓ PASSED

Running: tox -e py3 -- manila_tempest_plugin.api.test_share_revert_rbac
✓ PASSED (4/4 tests)
```

---

## Example 3: Scenario Test for Complex Workflow

### Jira Ticket
```
RHEL-67890: End-to-end test for volume migration workflow

Requirements:
- Create volume with data
- Attach to instance
- Detach volume
- Migrate volume to different backend
- Re-attach to instance
- Verify data integrity
```

### Invocation
```
/tempest-coverage RHEL-67890
```

### Expected Workflow

1. **Planning Phase**
```
Complex scenario detected - entering plan mode...

Plan:
1. Inherit from BaseVolumeScenarioTest
2. Create helper methods:
   - _create_volume_with_data()
   - _attach_volume()
   - _detach_volume()
   - _migrate_volume()
   - _verify_data()
3. Implement main test workflow
4. Add negative test for migration failure

Estimated complexity: HIGH (scenario test, ~15 min execution)
```

2. **User Approval**
```
User: "Looks good, proceed"
```

3. **Implementation**
```
Creating: cinder_tempest_plugin/scenario/test_volume_migration.py

Base class: ScenarioBaseClass
Clients: volumes_client, servers_client, compute_client

Tests implemented:
1. test_volume_migration_with_attached_instance()
2. test_volume_migration_data_integrity()
3. test_volume_migration_failure_rollback()
```

4. **Validation**
```
Running: tox -e pep8
✓ PASSED

Running: tox -e py3 -- cinder_tempest_plugin.scenario.test_volume_migration
⏳ Running (slow test, ~12 min)...
✓ PASSED (3/3 tests)
```

---

## Example 4: API Microversion Test

### Jira Ticket
```
RHEL-99999: Test Cinder volume reimage API (microversion 3.68)

Requirements:
- Test reimage with existing volume image
- Test requires microversion 3.68+
- Negative test for invalid image
```

### Expected Implementation

```python
from tempest.lib import decorators
from cinder_tempest_plugin.api import base

class VolumeReimageTest(base.BaseVolumeTest):
    """Test volume reimage functionality (microversion 3.68+)."""
    
    min_microversion = '3.68'
    max_microversion = 'latest'
    
    @decorators.idempotent_id('a1b2c3d4-5678-90ab-cdef-1234567890ab')
    @decorators.attr(type='smoke')
    def test_volume_reimage(self):
        """Test volume reimage with valid image.
        
        1. Create volume
        2. Create image from volume
        3. Reimage volume with new image
        4. Verify volume reimaged successfully
        """
        # Create volume
        volume = self.create_volume()
        
        # Create image
        image = self.images_client.create_image(
            name='test-image',
            disk_format='raw',
            container_format='bare'
        )['image']
        self.addCleanup(self.images_client.delete_image, image['id'])
        
        # Reimage volume (requires microversion 3.68+)
        self.volumes_client.reimage_volume(
            volume['id'],
            image_id=image['id']
        )
        
        # Wait for reimage completion
        waiters.wait_for_volume_resource_status(
            self.volumes_client,
            volume['id'],
            'available'
        )
        
        # Verify
        reimaged_volume = self.volumes_client.show_volume(
            volume['id']
        )['volume']
        
        self.assertEqual(image['id'], reimaged_volume['volume_image_metadata']['image_id'])
```

---

## Example 5: Negative Test Coverage

### Jira Ticket
```
RHEL-11111: Add negative tests for Glance image upload

Requirements:
- Test upload with invalid format
- Test upload exceeding quota
- Test upload to protected image
```

### Expected Implementation

```python
from tempest.lib import decorators
from tempest.lib import exceptions as lib_exc
from glance_tempest_plugin.tests.api import base

class ImageUploadNegativeTest(base.BaseImageTest):
    """Negative tests for image upload."""
    
    @decorators.idempotent_id('neg-1234-5678-90ab-cdef')
    @decorators.attr(type='negative')
    def test_image_upload_invalid_format(self):
        """Test image upload fails with invalid disk format."""
        image = self.create_image(
            name='invalid-format-image',
            disk_format='invalid',
            container_format='bare'
        )
        
        # Attempt upload - should fail
        self.assertRaises(
            lib_exc.BadRequest,
            self.image_client.store_image_file,
            image['id'],
            data='fake-image-data'
        )
    
    @decorators.idempotent_id('neg-abcd-ef12-3456-7890')
    @decorators.attr(type='negative')
    def test_image_upload_exceeds_quota(self):
        """Test image upload fails when quota exceeded."""
        # Set low quota
        self.admin_quotas_client.update_quota(
            self.tenant_id,
            image_size_total=1  # 1 byte quota
        )
        self.addCleanup(
            self.admin_quotas_client.update_quota,
            self.tenant_id,
            image_size_total=-1  # Reset
        )
        
        image = self.create_image(
            name='quota-test-image',
            disk_format='raw',
            container_format='bare'
        )
        
        # Upload should fail due to quota
        self.assertRaises(
            lib_exc.OverLimit,
            self.image_client.store_image_file,
            image['id'],
            data='x' * 1024  # 1KB data
        )
```

---

## Example 6: Handling Missing Repository

### Scenario
```
User has tempest core installed but missing cinder-tempest-plugin
```

### Expected Behavior

```
Skill Invocation: /tempest-coverage RHEL-12345 (Cinder feature)

Discovery Phase:
✓ Found tempest at ~/automation_projects/tempest
❌ cinder-tempest-plugin not found locally

Searched locations:
- ~/automation_projects/cinder-tempest-plugin
- ~/PycharmProjects/cinder-tempest-plugin

Response:
"The cinder-tempest-plugin repository is not available locally.

Options:
1. Provide the path to your local cinder-tempest-plugin
2. I can implement based on upstream structure at:
   https://opendev.org/openstack/cinder-tempest-plugin

Please advise how you'd like to proceed."
```

---

## Example 7: Memory-Driven Pattern Reuse

### First Usage
```
User: /tempest-coverage RHEL-11111 (Cinder volume extend test)

Claude discovers and saves to memory:
- Base class: BaseVolumeTest
- Client: self.volumes_client
- Cleanup: self.addCleanup(self.delete_volume, vol_id)
- Waiter: waiters.wait_for_volume_resource_status()

Memory saved: "Cinder volume tests use BaseVolumeTest and volumes_client"
```

### Second Usage (Same Session or Later)
```
User: /tempest-coverage RHEL-22222 (Cinder snapshot test)

Claude recalls from memory:
✓ Remembered: Cinder tests use BaseVolumeTest
✓ Remembered: Use self.volumes_client and self.snapshots_client
✓ Applying saved cleanup pattern

Implementation is faster with fewer searches needed!
```

---

## Tips for Best Results

### 1. Provide Clear Jira Tickets
```
Good:
"RHEL-12345: Test Manila share extend with RBAC
- Admin can extend any share
- Member can extend own share
- Reader cannot extend"

Bad:
"RHEL-12345: Fix share thing"
```

### 2. Specify Service Explicitly
```
Good: "Cinder volume backup RBAC tests"
Bad: "Backup tests" (which service?)
```

### 3. Mention Existing Coverage if Known
```
"Tests exist in test_volumes.py but missing RBAC coverage"
```

### 4. Indicate Complexity
```
"Simple API test for volume attach"
vs
"Complex scenario testing volume migration with data integrity"
```

### 5. Provide Acceptance Criteria
```
"Tests should verify:
- Positive case: operation succeeds
- Negative case: unauthorized fails with 403
- Edge case: handles large volumes"
```

---

## Common Patterns Discovered

### Cinder
- Base: `BaseVolumeTest`, `BaseVolumeAdminTest`
- Client: `volumes_client`, `snapshots_client`, `backups_client`
- Waiters: `wait_for_volume_resource_status`, `wait_for_volume_deletion`

### Manila
- Base: `BaseSharesTest`, `BaseSharesAdminTest`, `BaseSharesRbacTest`
- Client: `shares_v2_client`
- Waiters: `wait_for_share_status`, `wait_for_snapshot_status`

### Glance
- Base: `BaseImageTest`
- Client: `image_client`, `image_client_v2`
- Waiters: `wait_for_image_status`

### Generic Tempest
- Base: `BaseTestCase`, `BaseV2ComputeTest`
- Always use `addCleanup` for resources
- Use `data_utils.rand_name()` for unique names
