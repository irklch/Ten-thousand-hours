#!/usr/bin/env bash
set -euo pipefail

simulator_id=$(
  xcodebuild -showdestinations -project Ten-thousand-hours.xcodeproj -scheme TenThousandHours 2>/dev/null \
    | grep 'platform:iOS Simulator' \
    | grep 'name:iPhone' \
    | grep -v 'placeholder' \
    | sed -E 's/.*id:([^,]+),.*/\1/' \
    | head -n 1
)

if [[ -z "$simulator_id" ]]; then
  echo "No compatible iPhone simulator found" >&2
  exit 1
fi

echo "$simulator_id"
