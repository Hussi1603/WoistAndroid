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

if [ ! -f ios/Podfile ]; then
cat > ios/Podfile <<'POD'
platform :ios, '15.0'

ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. Run 'flutter pub get' first."
  end
  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}."
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      # permission_handler: nur die benötigten Berechtigungen einbauen
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] += [
        'PERMISSION_LOCATION=1',
        'PERMISSION_LOCATION_WHENINUSE=0',
        'PERMISSION_NOTIFICATIONS=1',
      ]
    end
  end
end
POD
else
  perl -pi -e "s/^#?\s*platform :ios, '[0-9.]+'/platform :ios, '15.0'/" ios/Podfile
fi

flutter pub get
echo "✅ Plattform-Projekte sind bereit."
