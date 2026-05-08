#!/bin/bash
# scripts/generate_mk.sh

mkdir -p bin tmp_libs

cat > Android.mk <<EOF
LOCAL_PATH := \$(my-dir)

EOF

echo 'ifneq ("$(USE_MINIMAL_FOSS_APPS)","true")' > apps.mk
echo 'PRODUCT_PACKAGES += \' >> apps.mk

for meta in bin/*.meta; do
    [ -e "$meta" ] || continue
    source "$meta"
    
    echo -e "\t$MODULE \\" >> apps.mk
    
    cat >> Android.mk <<EOF
include \$(CLEAR_VARS)
LOCAL_MODULE := $MODULE
LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES := bin/$APK
LOCAL_MODULE_CLASS := ETC
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_DEX_PREOPT := false
LOCAL_MODULE_RELATIVE_PATH := preinstall
EOF

    if [ -n "$OVERRIDES" ]; then
        echo "LOCAL_OVERRIDES_PACKAGES := $OVERRIDES" >> Android.mk
    fi

    if [ -n "$NATIVE_ARCH" ]; then
        unzip -o "bin/$APK" "lib/*" -d tmp_libs > /dev/null 2>&1 || true
        LIBS_STR=$(unzip -olv "bin/$APK" 2>/dev/null | grep -v Stored | sed -nE 's;.*(lib/'"$NATIVE_ARCH"'/.*);\t\1 \\;p')
        
        if [ "$NATIVE_ARCH" == "x86" ] || [ "$NATIVE_ARCH" == "armeabi-v7a" ]; then
            echo "LOCAL_MULTILIB := 32" >> Android.mk
        fi
        
        echo "LOCAL_PREBUILT_JNI_LIBS := \\" >> Android.mk
        echo -e "$LIBS_STR" >> Android.mk
    fi

    if [[ "$PACKAGE" == "com.google.android.gms" || "$PACKAGE" == "com.android.vending" ]]; then
        echo "LOCAL_PRIVILEGED_MODULE := true" >> Android.mk
    fi

    echo "include \$(BUILD_PREBUILT)" >> Android.mk
    echo "" >> Android.mk
done

cat >> apps.mk <<EOF

ifneq ("\$(USE_CALYX_MICROG)","true")
PRODUCT_PACKAGES += \\
	GmsCore \\
	GsfProxy \\
	FakeStore
endif

ifeq ("\$(USE_MINIMAL_FOSS_APPS_WITH_MICROG)","true")
PRODUCT_PACKAGES += \\
	GmsCore \\
	GsfProxy \\
	FakeStore
endif
endif
EOF

cat >> Android.mk <<EOF
include \$(CLEAR_VARS)
# Find all Android.mk files in subfolders, excluding the current one
SUB_MAKEFILES := \$(shell find \$(LOCAL_PATH) -maxdepth 2 -mindepth 2 -name Android.mk)

include \$(SUB_MAKEFILES)
EOF

rm -rf tmp_libs