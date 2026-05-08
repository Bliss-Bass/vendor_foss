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

# 3. Build Unified Flashable Zip (Magisk/KernelSU + TWRP)
echo "  -> Packaging Unified Magisk/Recovery Flashable zip..."

# Create module.prop for Magisk/KernelSU
cat > tmp_zip/module.prop <<EOF
id=vendor_foss_${MAIN_ARCH//-/_}
name=Vendor FOSS Apps ($MAIN_ARCH)
version=1.0.0
versionCode=1
author=vendor_foss
description=Systemless injection of F-Droid, MicroG, and FOSS apps.
EOF

# Create META-INF structure
mkdir -p tmp_zip/META-INF/com/google/android

# Create updater-script with #MAGISK tag for Magisk/KernelSU native install
cat > tmp_zip/META-INF/com/google/android/updater-script <<'EOF'
#MAGISK
# Dummy updater-script
# This file tells Magisk and KernelSU to natively install the zip as a module.
# The real recovery script is inside update-binary.
EOF

# Create update-binary execution script for TWRP fallback
cat > tmp_zip/META-INF/com/google/android/update-binary <<'EOF'
#!/sbin/sh
OUTFD=$2
ZIPFILE=$3
ui_print() { echo -e "ui_print $1\nui_print" >& $OUTFD; }

# Skip if running inside Magisk/KernelSU Manager (BOOTMODE=true)
if [ "$BOOTMODE" = "true" ]; then
    ui_print "- Magisk/KernelSU Manager detected."
    ui_print "- The module will be installed systemlessly."
    exit 0
fi

ui_print "Mounting system..."
mount /system 2>/dev/null
mount /system_root 2>/dev/null
mount -o rw,remount /system 2>/dev/null || mount -o rw,remount /system_root 2>/dev/null

SYS_PATH="/system"
if [ -d "/system_root/system" ]; then
    SYS_PATH="/system_root/system"
fi

# Safety check: Is the system partition actually writable?
if ! touch "$SYS_PATH/test_write" 2>/dev/null; then
    ui_print "*****************************************"
    ui_print "! ERROR: System partition is Read-Only !"
    ui_print "! Modern Android (10+) uses dynamic or !"
    ui_print "! EROFS partitions which cannot be     !"
    ui_print "! modified directly in recovery.       !"
    ui_print "! Please use Magisk/KernelSU Manager   !"
    ui_print "! to install this zip as a module!     !"
    ui_print "*****************************************"
    exit 1
fi
rm -f "$SYS_PATH/test_write" 2>/dev/null

ui_print "Extracting FOSS apps to $SYS_PATH..."
mkdir -p /tmp/foss_extract
unzip -oq "$ZIPFILE" 'system/*' -d /tmp/foss_extract/
cp -rf /tmp/foss_extract/system/* "$SYS_PATH/"
rm -rf /tmp/foss_extract

ui_print "Setting permissions..."
chmod -R 755 "$SYS_PATH/priv-app" "$SYS_PATH/app" "$SYS_PATH/etc/permissions" 2>/dev/null
find "$SYS_PATH/priv-app" "$SYS_PATH/app" -type f -name "*.apk" -exec chmod 644 {} + 2>/dev/null
find "$SYS_PATH/priv-app" "$SYS_PATH/app" -type f -name "*.so" -exec chmod 644 {} + 2>/dev/null
chmod 644 "$SYS_PATH/etc/permissions"/*.xml 2>/dev/null

ui_print "Install complete."
exit 0
EOF
chmod +x tmp_zip/META-INF/com/google/android/update-binary

# Set proper permissions in the staging folder BEFORE zipping!
# This is crucial for Magisk/KernelSU because Android requires 644 for system files.
find tmp_zip/system -type d -exec chmod 755 {} +
find tmp_zip/system -type f -exec chmod 644 {} +

# Build the final zip
(cd tmp_zip && zip -rq ../output/vendor_foss-$MAIN_ARCH.zip .)

# Cleanup
rm -rf tmp_zip tmp_magisk tmp_recovery

echo "Success: Unified Zip generated in output/ directory."