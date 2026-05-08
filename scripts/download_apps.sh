#!/bin/bash
# scripts/download_apps.sh

source scripts/config.sh

MAIN_ARCH=$1
SUB_ARCH=""
case $MAIN_ARCH in
    "x86_64") SUB_ARCH="x86" ;;
    "arm64-v8a") SUB_ARCH="armeabi-v7a" ;;
    "x86") SUB_ARCH="x86" ;;
    "armeabi-v7a") SUB_ARCH="armeabi-v7a" ;;
    *) echo "Usage: $0 <arch> (e.g., x86_64, arm64-v8a, x86, armeabi-v7a)"; exit 1 ;;
esac

mkdir -p bin tmp

get_fdroid_index() {
    if [ ! -f tmp/fdroid_index.xml ]; then
        for url in "${FDROID_MIRRORS[@]}"; do
            echo "Trying mirror: $url"
            if wget --connect-timeout=10 --tries=2 "${url}index.jar" -O tmp/index.jar; then
                unzip -p tmp/index.jar index.xml > tmp/fdroid_index.xml
                FDROID_ACTIVE_REPO="$url"
                return 0
            fi
        done
        echo "Failed to download F-Droid index."
        exit 1
    else
        FDROID_ACTIVE_REPO="${FDROID_MIRRORS[0]}"
    fi
}

download_app() {
    local package=$1
    local overrides=$2
    local repo_url=$3
    local index_file=$4
    local module_name=${5:-$package}

    echo "Processing $package for $MAIN_ARCH / $SUB_ARCH..."
    
    local apk=""
    local native=""
    local index=1
    
    while true; do
        apk="$(xmlstarlet sel -t -m '//application[id="'"$package"'"]/package['$index']' -v ./apkname "$index_file")"
        native="$(xmlstarlet sel -t -m '//application[id="'"$package"'"]/package['$index']' -v ./nativecode "$index_file")"
        
        if [ -z "$apk" ]; then break; fi
        if [ -z "$native" ] || echo "$native" | grep -q "$MAIN_ARCH" || echo "$native" | grep -q "$SUB_ARCH"; then break; fi
        
        index=$((index + 1))
    done

    if [ -z "$apk" ]; then
        apk="$(xmlstarlet sel -t -m '//application[id="'"$package"'"]/package[1]' -v ./apkname "$index_file")"
        native="$(xmlstarlet sel -t -m '//application[id="'"$package"'"]/package[1]' -v ./nativecode "$index_file")"
    fi

    if [ -n "$apk" ]; then
        echo "Found APK: $apk"
        
        # Verify integrity if file exists, delete if corrupt
        if [ -f "bin/$apk" ] && ! unzip -t "bin/$apk" >/dev/null 2>&1; then
            echo "Corrupt APK detected. Deleting and redownloading..."
            rm -f "bin/$apk"
        fi
        
        if [ ! -f "bin/$apk" ]; then
            local retries=0
            while ! wget --connect-timeout=10 "${repo_url%/}/$apk" -O "bin/$apk"; do 
                retries=$((retries+1))
                if [ "$retries" -ge 5 ]; then
                    echo "Failed to download $apk after 5 attempts."
                    exit 1
                fi
                sleep 1
            done
        fi
        
        # Meta info for generate_mk.sh
        echo "APK=\"$apk\"" > "bin/$apk.meta"
        echo "PACKAGE=\"$package\"" >> "bin/$apk.meta"
        echo "MODULE=\"$module_name\"" >> "bin/$apk.meta"
        echo "OVERRIDES=\"$overrides\"" >> "bin/$apk.meta"
        
        if [ -n "$native" ]; then
             if echo "$native" | grep -q "$MAIN_ARCH"; then
                 echo "NATIVE_ARCH=\"$MAIN_ARCH\"" >> "bin/$apk.meta"
             elif echo "$native" | grep -q "$SUB_ARCH"; then
                 echo "NATIVE_ARCH=\"$SUB_ARCH\"" >> "bin/$apk.meta"
             fi
        fi
    else
        echo "Could not find $package in $index_file"
    fi
}

get_fdroid_index

for app in "${FDROID_APPS[@]}"; do
    IFS=':' read -r pkg overrides <<< "$app"
    download_app "$pkg" "$overrides" "$FDROID_ACTIVE_REPO" "tmp/fdroid_index.xml"
done

if [ ! -f tmp/microg_index.xml ]; then
    wget --connect-timeout=10 --tries=2 "${MICROG_REPO}/index.jar" -O tmp/microg_index.jar
    unzip -p tmp/microg_index.jar index.xml > tmp/microg_index.xml
fi

for app in "${MICROG_APPS[@]}"; do
    IFS=':' read -r pkg module overrides <<< "$app"
    download_app "$pkg" "$overrides" "$MICROG_REPO" "tmp/microg_index.xml" "$module"
done