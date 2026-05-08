#!/bin/bash
# scripts/build_zips.sh

MAIN_ARCH=$1
if [ -z "$MAIN_ARCH" ]; then
    echo "Usage: $0 <arch>"
    exit 1
fi

echo -e "\n# Building Flashable Zips for $MAIN_ARCH..."

rm -rf tmp_zip tmp_magisk tmp_recovery
mkdir -p tmp_zip/system/etc/permissions output

# 1. Copy Permissions
if [ -f "permissions/foss-permissions.xml" ]; then
    cp permissions/foss-permissions.xml tmp_zip/system/etc/permissions/
fi

# 2. Stage Apps and Native Libraries
for meta in bin/*.meta; do
    [ -e "$meta" ] || continue
    source "$meta"

    # Determine target directory
    if [[ "$PACKAGE" == "com.google.android.gms" || "$PACKAGE" == "com.android.vending" ]]; then
        TARGET_DIR="system/priv-app/$MODULE"
    else
        TARGET_DIR="system/app/$MODULE"
    fi

    mkdir -p "tmp_zip/$TARGET_DIR"
    cp "bin/$APK" "tmp_zip/$TARGET_DIR/$MODULE.apk"

    # Extract and copy native libs if they exist
    if [ -n "$NATIVE_ARCH" ]; then
        # Map Android.mk NATIVE_ARCH to standard library paths
        case "$NATIVE_ARCH" in
            "arm64-v8a") LIB_DIR="arm64" ;;
            "armeabi-v7a") LIB_DIR="arm" ;;
            "x86_64") LIB_DIR="x86_64" ;;
            "x86") LIB_DIR="x86" ;;
            *) LIB_DIR="$NATIVE_ARCH" ;;
        esac
        
        mkdir -p "tmp_zip/$TARGET_DIR/lib/$LIB_DIR"
        unzip -j "bin/$APK" "lib/$NATIVE_ARCH/*.so" -d "tmp_zip/$TARGET_DIR/lib/$LIB_DIR/" >/dev/null 2>&1 || true
    fi
done

# 3. Build Magisk/KernelSU Module
echo "  -> Packaging Magisk/KernelSU module..."
mkdir -p tmp_magisk
cp -r tmp_zip/system tmp_magisk/
cat > tmp_magisk/module.prop <<EOF
id=vendor_foss_${MAIN_ARCH//-/_}
name=Vendor FOSS Apps ($MAIN_ARCH)
version=1.0.0
versionCode=1
author=vendor_foss
description=Systemless injection of F-Droid, MicroG, and FOSS apps.
EOF

(cd tmp_magisk && zip -rq ../output/vendor_foss-magisk-$MAIN_ARCH.zip .)

# 4. Build Recovery Flashable Zip
echo "  -> Packaging Recovery Flashable zip..."
mkdir -p tmp_recovery/META-INF/com/google/android
cp -r tmp_zip/system tmp_recovery/

# Dummy updater-script required by some recoveries
echo "# Dummy updater-script" > tmp_recovery/META-INF/com/google/android/updater-script

# Create update-binary execution script
cat > tmp_recovery/META-INF/com/google/android/update-binary <<'EOF'
#!/sbin/sh
OUTFD=$2
ZIPFILE=$3
ui_print() { echo -e "ui_print $1\nui_print" >& $OUTFD; }

ui_print "Mounting system..."
mount /system 2>/dev/null
mount /system_root 2>/dev/null
mount -o rw,remount /system 2>/dev/null || mount -o rw,remount /system_root 2>/dev/null

# Safety check: Is the system partition actually writable?
if ! touch /system/test_write 2>/dev/null && ! touch /system_root/test_write 2>/dev/null; then
    ui_print "*****************************************"
    ui_print "! ERROR: System partition is Read-Only !"
    ui_print "! Modern Android (10+) uses dynamic or !"
    ui_print "! EROFS partitions which cannot be     !"
    ui_print "! modified directly in recovery.       !"
    ui_print "! Please use the Magisk module instead.!"
    ui_print "*****************************************"
    exit 1
fi
rm -f /system/test_write /system_root/test_write 2>/dev/null

ui_print "Extracting FOSS apps..."
unzip -o "$ZIPFILE" 'system/*' -d /

ui_print "Setting permissions..."
chmod -R 755 /system/priv-app /system/app /system/etc/permissions 2>/dev/null
find /system/priv-app /system/app -type f -name "*.apk" -exec chmod 644 {} +
find /system/priv-app /system/app -type f -name "*.so" -exec chmod 644 {} +
chmod 644 /system/etc/permissions/*.xml 2>/dev/null

ui_print "Install complete."
exit 0
EOF
chmod +x tmp_recovery/META-INF/com/google/android/update-binary

(cd tmp_recovery && zip -rq ../output/vendor_foss-recovery-$MAIN_ARCH.zip .)

# Cleanup
rm -rf tmp_zip tmp_magisk tmp_recovery

echo "Success: Zips generated in output/ directory."