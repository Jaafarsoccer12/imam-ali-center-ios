#!/usr/bin/python3
"""Build and launch Imam Ali Center on this project's dedicated iPhone simulator."""
import fcntl
import json
import plistlib
import subprocess
import sys
import uuid
from pathlib import Path

PROJECT = Path(__file__).resolve().parent
CACHE = PROJECT / '.iac-preview'
NAME = 'IAC • App Preview'


def output(*args):
    return subprocess.check_output(args, text=True).strip()


def sim(*args):
    return ['xcrun', 'simctl', *args]


def choose_device(inventory):
    runtime_versions = {}
    for runtime in inventory['runtimes']:
        version = tuple(int(part) for part in runtime['version'].split('.'))
        if (runtime['isAvailable'] and '.iOS-' in runtime['identifier'] and version[0] >= 17):
            runtime_versions[runtime['identifier']] = (version, runtime)
    if not runtime_versions:
        raise ValueError('Install an iOS 17 or later simulator runtime in Xcode Settings > Components.')

    receipt = CACHE / 'device-id'
    known_ids = [receipt.read_text().strip()] if receipt.is_file() else []
    for device_id in known_ids:
        for runtime_id, devices in inventory['devices'].items():
            if runtime_id not in runtime_versions:
                continue
            for device in devices:
                if (device['udid'] == device_id and device['name'] == NAME and device['isAvailable']
                        and '.iPhone-' in device.get('deviceTypeIdentifier', '')):
                    return str(uuid.UUID(device_id)).upper(), runtime_versions[runtime_id][1]['name']

    for version, runtime in sorted(runtime_versions.values(), key=lambda item: item[0], reverse=True):
        types = runtime.get('supportedDeviceTypes')
        if not types:
            padded = (version + (0, 0))[:3]
            code = padded[0] * 65536 + padded[1] * 256 + padded[2]
            types = [t for t in inventory['devicetypes'] if t.get('minRuntimeVersion', 0) <= code
                     <= t.get('maxRuntimeVersion', 4294967295)]
        phones = [t for t in types if t['name'].startswith('iPhone ')]
        if not phones:
            continue
        preferred = ['iPhone 17', 'iPhone 17 Pro', 'iPhone 16', 'iPhone 15', 'iPhone 14']
        device_type = next((p for name in preferred for p in phones if p['name'] == name), phones[0])
        device_id = output(*sim('create', NAME, device_type['identifier'], runtime['identifier']))
        device_id = str(uuid.UUID(device_id)).upper()
        receipt.write_text(device_id + '\n')
        return device_id, runtime['name']
    raise ValueError('No compatible iPhone simulator type was found in the installed runtimes.')


def preview():
    xcode_project = PROJECT / 'ImamAliCenter.xcodeproj'
    if not xcode_project.exists():
        raise ValueError('Keep Preview.command beside ImamAliCenter.xcodeproj in the project folder.')
    device_id, runtime_name = choose_device(json.loads(output(*sim('list', '--json'))))
    print(f'Preparing {NAME} ({runtime_name}, {device_id})…', flush=True)
    subprocess.run(sim('bootstatus', device_id, '-b'), check=True)
    build_data = CACHE / 'DerivedData'
    subprocess.run(['xcodebuild', '-project', str(xcode_project), '-scheme', 'ImamAliCenter',
                    '-configuration', 'Debug', '-destination', f'platform=iOS Simulator,id={device_id}',
                    '-derivedDataPath', str(build_data), 'CODE_SIGNING_ALLOWED=NO', 'build'], check=True)
    app = build_data / 'Build' / 'Products' / 'Debug-iphonesimulator' / 'ImamAliCenter.app'
    with (app / 'Info.plist').open('rb') as info:
        bundle_id = plistlib.load(info)['CFBundleIdentifier']
    subprocess.run(sim('install', device_id, str(app)), check=True)
    subprocess.run(sim('launch', device_id, bundle_id), check=True)
    print(f'\nThe app is running on {NAME}.\nIn Simulator, choose File > Open Simulator > {runtime_name} > {NAME}.')


if __name__ == '__main__':
    try:
        CACHE.mkdir(exist_ok=True)
        with (CACHE / 'preview.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            preview()
    except BlockingIOError:
        sys.exit('A preview build is already running for this project.')
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as error:
        sys.exit(f'Could not start the preview. {error}')
