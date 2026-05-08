#!/bin/bash
# tag_release.sh

GMS_APK=$(ls bin/com.google.android.gms*.apk 2>/dev/null | head -n 1)

if [ -z "$GMS_APK" ]; then
    echo "MicroG APK not found! Please run ./update.sh first to download the files."
    exit 1
fi

if ! command -v aapt &> /dev/null; then
    echo "Error: 'aapt' is required to extract the version."
    exit 1
fi

# Extract the numeric versionCode directly from the package line
MICROG_VER=$(aapt dump badging "$GMS_APK" | grep "package:" | sed -nE "s/.*versionCode='([^']+)'.*/\1/p" | head -n 1)

if [ -z "$MICROG_VER" ]; then
    echo "Could not extract version from MicroG APK."
    exit 1
fi

echo "Creating tag v$MICROG_VER..."
git tag "v$MICROG_VER"
git push origin "v$MICROG_VER"
echo "Pushed v$MICROG_VER to GitHub! The release workflow should now start."