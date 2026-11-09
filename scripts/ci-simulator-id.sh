#!/usr/bin/env bash
set -euo pipefail

sdk_version=$(xcrun --sdk iphonesimulator --show-sdk-version)

xcrun simctl list --json | SDK_VERSION="$sdk_version" python3 -c '
import json, os, subprocess, sys

def version(text):
    return [int(part) for part in text.split(".")]

sdk_text = os.environ["SDK_VERSION"]
sdk = version(sdk_text)
data = json.load(sys.stdin)
runtimes = [
    runtime for runtime in data["runtimes"]
    if runtime["platform"] == "iOS" and runtime["isAvailable"] and version(runtime["version"]) <= sdk
]
if not runtimes:
    sys.exit("No available iOS simulator runtime for SDK " + sdk_text)
runtime = max(runtimes, key=lambda runtime: version(runtime["version"]))

for device in data["devices"].get(runtime["identifier"], []):
    if device["isAvailable"] and device["name"].startswith("iPhone"):
        print(device["udid"])
        sys.exit(0)

iphones = [t for t in runtime.get("supportedDeviceTypes", []) if t["name"].startswith("iPhone")]
if not iphones:
    sys.exit("Runtime " + runtime["name"] + " supports no iPhone device types")
created = subprocess.run(
    ["xcrun", "simctl", "create", "CI iPhone", iphones[-1]["identifier"], runtime["identifier"]],
    check=True, capture_output=True, text=True,
)
print(created.stdout.strip())
'
