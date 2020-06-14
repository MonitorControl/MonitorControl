#!/usr/bin/env bash

###################################
# MonitorControl                  #
# Script to publish a new release #
###################################

# /!\ Very much WIP - Use carefully /!\

# Requirements:
# - The project configured successfully
# - xcodebuild
# - create-dmg
# - git

# Usage:
# ./scripts/publish_release.sh "<Path> to private key"

set -eu

if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    echo "Usage: ./scripts/publish_release.sh \"<Path> to private key\""
    exit 1
fi

# Script Config
SCRIPT_VERSION="1.0.0"
DEV_MODE="true"

# Script variables
APP_NAME="MonitorControl"
APP_VERSION="$(sed -n '/MARKETING_VERSION/{s/MARKETING_VERSION = //;s/;//;s/^[[:space:]]*//;p;q;}' ./${APP_NAME}.xcodeproj/project.pbxproj)"

DMG_NAME="${APP_NAME}-${APP_VERSION}.dmg"
TEMP_DIR="$(mktemp -d "${TMPDIR}${APP_NAME}.XXXXXX")"
GIT_INITIAL_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Colors
COLOR_RED="\e[31m"
COLOR_GREEN="\e[32m"
COLOR_YELLOW="\e[33m"
COLOR_BLUE="\e[34m"
COLOR_NORMAL="\e[0m"

# Log
i="${COLOR_BLUE}ℹ︎${COLOR_NORMAL} "
c="${COLOR_GREEN}✓${COLOR_NORMAL} "
x="${COLOR_RED}x${COLOR_NORMAL} "

# Setup
echo -e "----"
echo -e "${APP_NAME} Release Script v${SCRIPT_VERSION}"
echo -e "${i}Releasing v${APP_VERSION}"
echo -e "${i}Temp folder: ${TEMP_DIR}"
echo -e "----"
echo -e ""

if [ "$DEV_MODE" == true ]; then
    echo -e "${COLOR_YELLOW}----"
    echo -e "/!\\ Dev mode enabled /!\\"
    echo -e "The script will not push changes upstream"
    echo -e "----${COLOR_NORMAL}"
fi

# Step 1 - Compilation
if which xcodebuild > /dev/null; then
    echo -e ""
    echo -e "${i}1. Compiling app…"
    xcodebuild clean >/dev/null
    echo -e "${c}Build folder cleaned successfully"
    xcodebuild -scheme "${APP_NAME}" -configuration Release CONFIGURATION_BUILD_DIR="${TEMP_DIR}" build >/dev/null
    echo -e "${c}App built successfully"
else
    echo -e "${x}warning: xcodebuild not installed"
fi

# Step 2 - Commit changes to master
if which git > /dev/null; then
    echo -e ""
    echo -e "${i}2. Commiting changes to master…"
    git add -A
    git commit -S -m ":tada: Release v${APP_VERSION}"
    git tag "v${APP_VERSION}"
    if [ "$DEV_MODE" == true ]; then
        echo -e "${i}Dev mode enabled: Skipping push"
    else
        git push
    fi
    echo -e "${c}Commit to master successful"
else
    echo -e "${x}warning: git not installed"
fi

# Step 3 - Generate dmg
if which create-dmg > /dev/null; then
    echo -e ""
    echo -e "${i}3. Generating dmg…"
    create-dmg "${TEMP_DIR}/${APP_NAME}.app" "${TEMP_DIR}"
    mv "${TEMP_DIR}/${APP_NAME} ${APP_VERSION}.dmg" "${TEMP_DIR}/${DMG_NAME}"
    echo -e "${c}Dmg built successfully"
else
    echo -e "${x}warning: create-dmg not installed"
fi

# Step 4 - Sign update (for Sparkle)
if which openssl > /dev/null; then
    echo -e ""
    echo -e "${i}4. Signing update…"
    SIGNATURE="$(openssl dgst -sha1 -binary < "${TEMP_DIR}/${DMG_NAME}" | openssl dgst -sha1 -sign "$1" | openssl enc -base64)"
    echo -e "${c}Signature generated : ${SIGNATURE}"
else
    echo -e "${x}warning: openssl not installed"
fi

# Step 5 - Generate appcast item (for Sparkle)
# TODO: Generate a real item
echo -e ""
echo -e "${i}5. Generating new appcast item…"
touch "${TEMP_DIR}/updates.xml"
echo -e "${c}Appcast item generated successfully"

# Step 6 - Commit changes to gh-pages
if which git > /dev/null; then
    echo -e ""
    echo -e "${i}6. Commiting changes to gh-pages…"
    git checkout gh-pages
    cp -f "./updates.xml" "${TEMP_DIR}/updates.xml"
    git add -A
    git commit -S -m ":tada: Release v${APP_VERSION}"
    if [ "$DEV_MODE" == true ]; then
        echo -e "${i}Dev mode enabled: Skipping push"
    else
        git push
    fi
    git checkout "${GIT_INITIAL_BRANCH}"
    echo -e "${c}Commit to gh-pages successful"
else
    echo -e "${x}warning: git not installed"
fi

# Step 7 - Create new github release
# TODO: Use Github API to create a release 

# Step 8 - Cleanup
echo -e ""
if [ "$DEV_MODE" == true ]; then
    echo -e "${i}9. Dev mode enabled: Skipping Cleanup"
    open "${TEMP_DIR}"
else
    echo -e "${i}9. Cleaning up remaining files…"
    rm -rf "${TEMP_DIR}"
    echo -e "${c}Cleanup done"
fi
