#!/usr/bin/env bash
# Starts the Firebase emulators and keeps their data in emulator-data/
# between runs.
#
# - On start, loads emulator-data/ if it exists.
# - Saves every 60 seconds while running (set EMULATOR_SAVE_INTERVAL to change),
#   so a crash or a reboot loses at most the last minute.
# - On Ctrl+C, saves once more before stopping the emulators.
#
# To start from empty data, stop the emulators and delete emulator-data/.
set -uo pipefail
cd "$(dirname "$0")/.."

PROJECT=demo-myyatra
DATA=emulator-data
INTERVAL=${EMULATOR_SAVE_INTERVAL:-60}

# The emulators need Java 21+. If the current Java is older or missing, use
# Homebrew's openjdk@21 when it is installed.
java_major() { java -version 2>&1 | sed -nE 's/.*version "([0-9]+).*/\1/p' | head -1; }
if [ "$(java_major || echo 0)" -lt 21 ] 2>/dev/null || ! command -v java >/dev/null; then
  for j in /opt/homebrew/opt/openjdk@21 /usr/local/opt/openjdk@21; do
    if [ -d "$j" ]; then
      export JAVA_HOME="$j"
      export PATH="$JAVA_HOME/bin:$PATH"
      break
    fi
  done
fi

save() {
  # Export to a temp folder first so a failed export never damages the last
  # good copy.
  rm -rf "$DATA.tmp"
  if firebase emulators:export "$DATA.tmp" --project "$PROJECT" --force >/dev/null 2>&1; then
    rm -rf "$DATA.old"
    [ -d "$DATA" ] && mv "$DATA" "$DATA.old"
    mv "$DATA.tmp" "$DATA" && rm -rf "$DATA.old"
    return 0
  fi
  rm -rf "$DATA.tmp"
  return 1
}

args=(--project "$PROJECT")
if [ -f "$DATA/firebase-export-metadata.json" ]; then
  args+=(--import="$DATA")
  echo "Loading saved emulator data from $DATA/"
fi

# Run the emulators in their own process group so Ctrl+C reaches this script
# first and we can save before they stop.
set -m
firebase emulators:start "${args[@]}" &
EMU=$!
set +m

stop() {
  trap - INT TERM
  echo
  echo "Saving emulator data to $DATA/ ..."
  if save; then echo "Saved."; else echo "Save failed; keeping the previous copy."; fi
  kill -INT "$EMU" 2>/dev/null
  wait "$EMU" 2>/dev/null
  exit 0
}
trap stop INT TERM

while kill -0 "$EMU" 2>/dev/null; do
  sleep "$INTERVAL" &
  wait $! 2>/dev/null
  kill -0 "$EMU" 2>/dev/null && save
done
wait "$EMU"
