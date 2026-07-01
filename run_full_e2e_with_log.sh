#!/bin/bash
# Zyppi Ride — full E2E suite with persistent logging.
# Boots the configured Android emulator (if not already running), runs the
# integration_test/ suite via run_e2e_tests.sh, and snapshots stdout + reports
# into test_results/runs/<timestamp>/.

EMULATOR_ID="${EMULATOR_ID:-Pixel_9_API_35}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="test_results/runs/${TIMESTAMP}"
mkdir -p "${RUN_DIR}/reports"

echo "── Zyppi Ride E2E run ${TIMESTAMP} ──"
echo "Output directory: ${RUN_DIR}"

# 1. Boot the emulator if no Android device is already attached.
if flutter devices 2>/dev/null | grep -q "emulator-"; then
  echo "Emulator already running — skipping launch."
else
  echo "Launching emulator: ${EMULATOR_ID}"
  flutter emulators --launch "${EMULATOR_ID}" >/dev/null 2>&1 &
  echo "Waiting for emulator to attach (up to 180 s)..."
  WAIT=0
  until flutter devices 2>/dev/null | grep -q "emulator-"; do
    sleep 5
    WAIT=$((WAIT + 5))
    if [ "${WAIT}" -ge 180 ]; then
      echo "Timed out waiting for emulator." >&2
      exit 2
    fi
  done
  # Give Android a moment past the lock screen before driving Flutter at it.
  sleep 15
fi

# 2. Identify the attached emulator id.
DEVICE_ID="$(flutter devices 2>/dev/null | grep "emulator-" | head -1 | awk -F'•' '{print $2}' | xargs)"
if [ -z "${DEVICE_ID}" ]; then
  echo "Could not resolve a device id." >&2
  exit 3
fi
echo "Device: ${DEVICE_ID}"

# 3. Capture device + Flutter context for the report.
{
  echo "── flutter --version ──"
  flutter --version
  echo
  echo "── flutter devices ──"
  flutter devices
} > "${RUN_DIR}/flutter.log" 2>&1

# 4. Run the existing E2E wrapper, tee stdout+stderr to e2e.log.
START="$(date +%s)"
set +e
./run_e2e_tests.sh -d "${DEVICE_ID}" -s all -v 2>&1 | tee "${RUN_DIR}/e2e.log"
EXIT_CODE=${PIPESTATUS[0]}
set -e
END="$(date +%s)"
DURATION=$((END - START))

# 5. Snapshot the generated reports.
cp -R test_reports/*.html test_reports/*.json test_reports/*.md test_reports/*.xml \
    "${RUN_DIR}/reports/" 2>/dev/null || true

# 6. Write summary.
cat > "${RUN_DIR}/summary.txt" <<EOF
Run timestamp : ${TIMESTAMP}
Device        : ${DEVICE_ID}
Suite         : all
Exit code     : ${EXIT_CODE}
Duration      : ${DURATION}s
Log           : ${RUN_DIR}/e2e.log
Reports       : ${RUN_DIR}/reports/
EOF

echo
echo "── Summary ──"
cat "${RUN_DIR}/summary.txt"

exit ${EXIT_CODE}
