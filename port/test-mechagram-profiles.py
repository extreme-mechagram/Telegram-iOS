"""Verify expiration renewal against the real bundled CMS profile payloads."""
from datetime import datetime, timedelta, timezone
import importlib.util
from pathlib import Path
import plistlib
import uuid

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('profiles', root / 'port/prepare-mechagram-profiles.py')
profiles = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profiles)

now = datetime(2026, 11, 5, 12, 30, tzinfo=timezone(timedelta(hours=3)))
uuids = set()
count = 0
for path in (root / 'build-system/fake-codesigning/profiles').glob('*.mobileprovision'):
    raw = path.read_bytes()
    start = raw.index(b'<?xml')
    end = raw.index(b'</plist>', start) + len(b'</plist>')
    original = plistlib.loads(raw[start:end])
    original_expiration = original['ExpirationDate']
    updated = profiles.prepare_profile(original, 'org.mechagram.message', now=now)
    # Round-trip the same plist serialization used before CMS signing in CI.
    result = plistlib.loads(plistlib.dumps(updated))
    assert result['CreationDate'] == datetime(2026, 11, 5, 9, 30), path
    assert result['ExpirationDate'] == datetime(2027, 11, 5, 9, 30), path
    assert result['TimeToLive'] == 365, path
    assert original['ExpirationDate'] == original_expiration, path
    assert result['DeveloperCertificates'] == original['DeveloperCertificates'], path
    assert 'ph.telegra.Telegraph' not in str(result['Entitlements']), path
    assert 'org.mechagram.message' in str(result['Entitlements']), path
    assert str(uuid.UUID(result['UUID'])).upper() == result['UUID'], path
    assert result['UUID'] not in uuids, path
    uuids.add(result['UUID'])
    count += 1
assert count == 9, count
print(f'Mechagram: expiration, UTC dates, UUIDs, certificates and bundle IDs verified for {count} real profiles')
