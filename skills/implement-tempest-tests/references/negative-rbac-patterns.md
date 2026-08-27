# Negative and RBAC Test Patterns

Reference for implementing negative tests and RBAC tests following Tempest standards.

---

## Negative Test Pattern

Negative tests verify that the API correctly rejects invalid operations.

```python
@decorators.idempotent_id('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx')
@decorators.attr(type=['negative'])
def test_delete_backing_up_volume_fails(self):
    """Verify delete is rejected when volume is in backing-up status."""
    volume = self.create_volume()
    # Trigger the state that makes delete invalid
    backup = self.backups_client.create_backup(
        volume_id=volume['id'])['backup']
    waiters.wait_for_backup_resource_status(
        self.backups_client, backup['id'], 'available')
    # Attempt the operation that should fail
    self.assertRaises(
        lib_exc.Conflict,
        self.volumes_client.delete_volume,
        volume['id']
    )
```

**Key rules:**
- `@decorators.attr(type=['negative'])` is required
- Use `self.assertRaises(lib_exc.{ExceptionClass}, ...)` — import from `tempest.lib import exceptions as lib_exc`
- The operation being tested as "should fail" goes inside `assertRaises`
- Test goes in a `_negative`-suffixed file
- Common exception classes: `lib_exc.Conflict` (409), `lib_exc.BadRequest` (400), `lib_exc.Forbidden` (403), `lib_exc.NotFound` (404)

---

## RBAC Test Pattern

RBAC tests verify that each role has the correct level of access.

```python
class VolumeMultiattachRbacTest(base.BaseVolumeRbacTest):
    """RBAC tests for volume multi-attach feature."""

    credentials = ['admin', 'primary', 'alt']

    @classmethod
    def setup_credentials(cls):
        super().setup_credentials()

    @decorators.idempotent_id('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx')
    @decorators.attr(type=['rbac'])
    def test_volume_multiattach_as_admin(self):
        """Admin can enable multi-attach."""
        volume = self.admin_volumes_client.create_volume(
            size=1, multiattach=True)['volume']
        self.addCleanup(
            self.admin_volumes_client.delete_volume, volume['id'])
        waiters.wait_for_volume_resource_status(
            self.admin_volumes_client, volume['id'], 'available')
        self.assertTrue(volume['multiattach'])

    @decorators.idempotent_id('yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy')
    @decorators.attr(type=['rbac'])
    def test_volume_multiattach_as_member(self):
        """Member can enable multi-attach."""
        volume = self.volumes_client.create_volume(
            size=1, multiattach=True)['volume']
        self.addCleanup(
            self.volumes_client.delete_volume, volume['id'])
        waiters.wait_for_volume_resource_status(
            self.volumes_client, volume['id'], 'available')
        self.assertTrue(volume['multiattach'])

    @decorators.idempotent_id('zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz')
    @decorators.attr(type=['rbac'])
    def test_volume_multiattach_as_reader_denied(self):
        """Reader cannot enable multi-attach."""
        self.assertRaises(
            lib_exc.Forbidden,
            self.reader_volumes_client.create_volume,
            size=1, multiattach=True
        )
```

**Key rules:**
- Inherit from `BaseVolumeRbacTest` (or the equivalent for the service)
- `credentials = ['admin', 'primary', 'alt']` (the three roles)
- One test method per role: admin, member, reader
- `@decorators.attr(type=['rbac'])` on each method
- Reader tests typically use `assertRaises(lib_exc.Forbidden, ...)`
- RBAC tests go in a `_rbac`-suffixed file

---

## Scenario Test Pattern

Scenario tests verify multi-step end-to-end workflows.

```python
class VolumeConcurrentBootScenarioTest(base.BaseVolumeScenarioTest):
    """Scenario test for concurrent volume boot."""

    @decorators.idempotent_id('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx')
    @decorators.attr(type=['slow'])
    def test_concurrent_boot_10_instances(self):
        """Verify 10 instances can boot from volume concurrently."""
        volumes = []
        for _ in range(10):
            vol = self.create_volume(imageRef=self.image_ref)
            volumes.append(vol)
        # Boot instances concurrently
        servers = []
        for vol in volumes:
            server = self._boot_instance_from_volume(vol['id'])
            servers.append(server)
        # Verify all reached ACTIVE
        for server in servers:
            waiters.wait_for_server_status(
                self.servers_client, server['id'], 'ACTIVE')
```

**Key rules:**
- `@decorators.attr(type=['slow'])` for scenario tests
- Scenario tests go in files without a specific qualifier, or `_scenario`-suffixed
- Use helper methods (`create_volume`, `_boot_instance_from_volume`) that handle cleanup
- Each scenario must be independent (no shared setup across methods)
