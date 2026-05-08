#!/bin/bash
# set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
LT_BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check for required dependencies
REQUIRED_CMDS="wget unzip zip xmlstarlet aapt grep sed"
MISSING_CMDS=""
for cmd in $REQUIRED_CMDS; do
    if ! command -v $cmd &> /dev/null; then
        MISSING_CMDS="$MISSING_CMDS $cmd"
    fi
done

if [ -n "$MISSING_CMDS" ]; then
    echo -e "${RED}Error: Missing required dependencies:${NC}$MISSING_CMDS"
    echo -e "Please install them before running this script."
    echo -e "Example (Debian/Ubuntu): sudo apt-get install wget unzip xmlstarlet aapt"
    exit 1
fi

CLEAN=0
PRESELECTED_ARCH=""

for arg in "$@"; do
    case $arg in
        --clean|-c)
            CLEAN=1
            ;;
        1|"ABI:x86_64 & ABI2:x86"|x86_64)
            PRESELECTED_ARCH="x86_64"
            ;;
        2|"ABI:arm64-v8a & ABI2:armeabi-v7a"|arm64-v8a)
            PRESELECTED_ARCH="arm64-v8a"
            ;;
        3|"ABI:x86"|x86)
            PRESELECTED_ARCH="x86"
            ;;
        4|"ABI:armeabi-v7a"|armeabi-v7a)
            PRESELECTED_ARCH="armeabi-v7a"
            ;;
    esac
done

if [ "$CLEAN" == "1" ]; then
    echo -e "${LT_BLUE}# Cleaning up build directories...${NC}"
    rm -Rf bin tmp tmp_libs permissions apps.mk Android.mk output
    echo -e "${GREEN}# Clean complete.${NC}"
    # If ONLY clean was passed and no arch was provided, exit here safely
    if [ -z "$PRESELECTED_ARCH" ] && [ "$#" -eq 1 ]; then
        exit 0
    fi
fi

if [ -z "$PRESELECTED_ARCH" ]; then
    PS3='Which device type do you plan on building?: '
    echo -e "${YELLOW}(default is 'ABI:x86_64 & ABI2:x86')"
    TMOUT=10
    options=("ABI:x86_64 & ABI2:x86"
             "ABI:arm64-v8a & ABI2:armeabi-v7a"
             "ABI:x86"
             "ABI:armeabi-v7a")
    echo -e "Timeout in $TMOUT sec.${NC}"
    select opt in "${options[@]}"
    do
        case $opt in
            "ABI:x86_64 & ABI2:x86") PRESELECTED_ARCH="x86_64"; break ;;
            "ABI:arm64-v8a & ABI2:armeabi-v7a") PRESELECTED_ARCH="arm64-v8a"; break ;;
            "ABI:x86") PRESELECTED_ARCH="x86"; break ;;
            "ABI:armeabi-v7a") PRESELECTED_ARCH="armeabi-v7a"; break ;;
            *) echo "invalid option $REPLY";;
        esac
    done
    if [ -z "$PRESELECTED_ARCH" ]; then
        PRESELECTED_ARCH="x86_64"
    fi
fi

echo -e "${LT_BLUE}# Starting FOSS update for $PRESELECTED_ARCH...${NC}"

bash scripts/download_apps.sh "$PRESELECTED_ARCH"
bash scripts/generate_mk.sh
bash scripts/generate_perms.sh
bash scripts/build_zips.sh "$PRESELECTED_ARCH"

echo -e "${GREEN}# DONE${NC}"