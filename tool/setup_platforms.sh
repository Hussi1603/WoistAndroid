#!/usr/bin/env bash
# Erzeugt die Android- und iOS-Projektordner und trägt alle nötigen
# Berechtigungen (Standort im Hintergrund usw.) ein.
# Kann beliebig oft ausgeführt werden.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Wo ist?"

if [ ! -d android ] || [ ! -d ios ]; then
  flutter create --org de.woist --project-name woist --platforms android,ios .
fi
# Von "flutter create" erzeugten Beispiel-Test entfernen (passt nicht zur App).
if [ -f test/widget_test.dart ] && grep -q MyApp test/widget_test.dart; then
  rm test/widget_test.dart
fi

# ---------------- Android ----------------
MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q ACCESS_BACKGROUND_LOCATION "$MANIFEST"; then
  perl -0pi -e 's|(\s*<application)|
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
$1|' "$MANIFEST"
fi
perl -pi -e 's|android:label="[^"]*"|android:label="'"$APP_NAME"'"|' "$MANIFEST"

for f in android/app/build.gradle.kts android/app/build.gradle; do
  [ -f "$f" ] && perl -pi -e 's/minSdk(Version)?\s*=?\s*flutter\.minSdkVersion/minSdk = 24/' "$f"
done

# ---------------- iOS ----------------
python3 - "$APP_NAME" <<'PY'
import plistlib, sys
path = "ios/Runner/Info.plist"
with open(path, "rb") as f:
    p = plistlib.load(f)
p["CFBundleDisplayName"] = sys.argv[1]
p["NSLocationWhenInUseUsageDescription"] = (
    "Damit du deinen Standort mit deinen Freunden teilen und sie auf der Karte sehen kannst.")
p["NSLocationAlwaysAndWhenInUseUsageDescription"] = (
    "Damit deine Freunde dich auch sehen, wenn die App im Hintergrund ist.")
p["NSLocationAlwaysUsageDescription"] = p["NSLocationAlwaysAndWhenInUseUsageDescription"]
modes = p.get("UIBackgroundModes", [])
for m in ("location", "fetch"):
    if m not in modes:
        modes.append(m)
p["UIBackgroundModes"] = modes
with open(path, "wb") as f:
    plistlib.dump(p, f)
PY

perl -pi -e 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' \
  ios/Runner.xcodeproj/project.pbxproj

# Plugins kommen über den Swift Package Manager – kein Podfile nötig.
# Falls doch eins existiert (ältere Flutter-Version), Mindestversion anheben.
if [ -f ios/Podfile ]; then
  perl -pi -e "s/^#?\s*platform :ios, '[0-9.]+'/platform :ios, '15.0'/" ios/Podfile
fi

flutter pub get
echo "✅ Plattform-Projekte sind bereit."
