#!/usr/bin/env bash
# Regenerate the fastlane phone screenshots on a connected, unlocked Android
# device using demo data. Installs a throwaway debug build with a different
# application id, so the real Planova install and its data are never touched.
set -euo pipefail
cd "$(dirname "$0")/../.."
P=fr.rvier.planova.demo
OUT=fastlane/metadata/android/en-US/images/phoneScreenshots
GRADLE=android/app/build.gradle.kts

sed -i 's/applicationId = "fr.rvier.planova"/applicationId = "'"$P"'"/' "$GRADLE"
trap 'git checkout -q -- "$GRADLE" pubspec.lock; adb shell svc power stayon false' EXIT
flutter build apk --debug --target-platform android-arm64
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell svc power stayon usb

# Point the demo dailies at today so the calendar has content on the current day
TODAY=$(date +%Y%m%d); TMP=$(mktemp -d); cp -r tool/screenshots/demo "$TMP/Org"
i=0
for off in -3 -2 -1 0 3 7 14; do
  src=(20260908 20260909 20260910 20260911 20260914 20260918 20260925)
  d=$(date -d "$off day" +%Y%m%d)
  mv "$TMP/Org/dailies/${src[$i]}.md" "$TMP/Org/dailies/$d.md.new"; i=$((i+1))
done
for f in "$TMP"/Org/dailies/*.new; do mv "$f" "${f%.new}"; done

adb shell pm grant $P android.permission.POST_NOTIFICATIONS || true
adb shell appops set $P SCHEDULE_EXACT_ALARM allow || true
adb shell monkey -p $P -c android.intent.category.LAUNCHER 1 >/dev/null; sleep 5
adb shell am force-stop $P
adb push "$TMP/Org" /data/local/tmp/demo >/dev/null
adb shell "run-as $P sh -c 'rm -rf app_flutter/Org; mkdir -p app_flutter; cp -r /data/local/tmp/demo app_flutter/Org'"
adb shell rm -rf /data/local/tmp/demo

shot() { adb exec-out screencap -p > "$OUT/$1.png"; }
launch() { adb shell monkey -p $P -c android.intent.category.LAUNCHER 1 >/dev/null; sleep 7; }
launch; shot 1
adb shell input tap 848 1066; sleep 2; shot 2; adb shell input keyevent KEYCODE_BACK; sleep 1
adb shell input tap 540 2260; sleep 2; shot 3
adb shell input tap 900 2260; sleep 2; shot 4
adb shell am force-stop $P
adb shell "run-as $P sh -c 'sed -i \"s|<map>|<map>\n    <int name=\\\"flutter.theme_mode\\\" value=\\\"2\\\" />|\" shared_prefs/FlutterSharedPreferences.xml'"
launch; shot 5
adb shell input tap 540 2260; sleep 2; shot 6
adb shell am force-stop $P; adb uninstall $P
echo "Screenshots written to $OUT"
