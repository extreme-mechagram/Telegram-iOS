"""Adapt the repository's self-signed verification profiles, not device signing."""
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import uuid


def select_openssl():
    # Homebrew OpenSSL is keg-only; macOS may otherwise select /usr/bin/openssl (LibreSSL).
    candidates = [
        Path('/opt/homebrew/opt/openssl@3/bin/openssl'),
        Path('/usr/local/opt/openssl@3/bin/openssl'),
    ]
    executable = next((str(path) for path in candidates if path.is_file()), None)
    executable = executable or shutil.which('openssl')
    if executable is None:
        raise RuntimeError('OpenSSL executable was not found')
    version = subprocess.check_output([executable, 'version'], text=True).strip()
    # LibreSSL and OpenSSL 1.x do not accept OpenSSL 3's -legacy option.
    legacy_options = ['-legacy'] if version.startswith('OpenSSL 3.') else []
    print(f'Profile signing tool: {executable} ({version})', flush=True)
    return executable, legacy_options


def run_openssl(executable, *arguments):
    result = subprocess.run([executable, *arguments], capture_output=True)
    if result.returncode:
        # Never print stdout: PKCS#12 conversion can contain private key material.
        detail = result.stderr.decode('utf-8', errors='replace').strip()
        raise RuntimeError(f'OpenSSL {arguments[0]} failed: {detail}')
    return result.stdout


def replace_bundle(value, bundle):
    if isinstance(value, str):
        return value.replace('ph.telegra.Telegraph', bundle)
    if isinstance(value, list):
        return [replace_bundle(item, bundle) for item in value]
    if isinstance(value, dict):
        return {key: replace_bundle(item, bundle) for key, item in value.items()}
    return value


def prepare_profile(original, bundle, now=None):
    data = replace_bundle(original, bundle)
    instant = now or datetime.now(timezone.utc)
    # Apple plist dates are UTC; Python 3.11's plist writer expects naive dates.
    if instant.tzinfo is not None:
        instant = instant.astimezone(timezone.utc).replace(tzinfo=None)
    data['CreationDate'] = instant
    data['ExpirationDate'] = instant + timedelta(days=365)
    data['TimeToLive'] = 365
    data['UUID'] = str(uuid.uuid4()).upper()
    return data


def main():
    root = Path(__file__).resolve().parent.parent
    bundle = json.loads((root / 'build-system/appstore-configuration.json').read_text())['bundle_id']
    signing = root / 'build-system/fake-codesigning'
    executable, legacy_options = select_openssl()
    count = 0
    with tempfile.TemporaryDirectory() as directory:
        pem = Path(directory) / 'verification.pem'
        run_openssl(executable, 'pkcs12', *legacy_options, '-in', str(signing / 'certs/SelfSigned.p12'), '-passin', 'pass:', '-nodes', '-out', str(pem))
        for profile in (signing / 'profiles').glob('*.mobileprovision'):
            original = run_openssl(executable, 'smime', '-inform', 'der', '-verify', '-noverify', '-in', str(profile))
            data = prepare_profile(plistlib.loads(original), bundle)
            source = Path(directory) / 'profile.plist'
            source.write_bytes(plistlib.dumps(data))
            run_openssl(executable, 'smime', '-sign', '-nodetach', '-in', str(source), '-outform', 'DER', '-out', str(profile), '-signer', str(pem), '-inkey', str(pem))
            count += 1
    print(f'Prepared {count} verification profiles for {bundle}', flush=True)


if __name__ == '__main__':
    main()
