#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
OUTPUT_DIR="${PROJECT_DIR}/dist"
APP_DIR="${OUTPUT_DIR}/Claude Account Manager.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
BUILD_ARCHS_VALUE="${BUILD_ARCHS:-arm64}"
if [ -z "${MACOS_SDK_OVERRIDE:-}" ]; then
  if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
  else
    SDK_PATH="$(xcrun --show-sdk-path)"
  fi
else
  SDK_PATH="${MACOS_SDK_OVERRIDE}"
fi
MODULE_CACHE_DIR="${PROJECT_DIR}/.build/ModuleCache"

mkdir -p "${MODULE_CACHE_DIR}"

ARCH_ARGS=()
for architecture in ${(z)BUILD_ARCHS_VALUE}; do
  ARCH_ARGS+=(--arch "${architecture}")
done

export SDKROOT="${SDK_PATH}"
export CLANG_MODULE_CACHE_PATH="${MODULE_CACHE_DIR}"
export SWIFTPM_MODULECACHE_OVERRIDE="${MODULE_CACHE_DIR}"

cd "${PROJECT_DIR}"
swift build --disable-sandbox -c release "${ARCH_ARGS[@]}"
BIN_DIR="$(swift build --disable-sandbox -c release "${ARCH_ARGS[@]}" --show-bin-path)"

mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp "${BIN_DIR}/ClaudeAccountManager" "${MACOS_DIR}/ClaudeAccountManager"
cp "${PROJECT_DIR}/Resources/AppInfo.plist" "${CONTENTS_DIR}/Info.plist"

if [ -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]; then
  cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

if [ -f "${PROJECT_DIR}/Resources/AppIcon_1024.png" ]; then
  cp "${PROJECT_DIR}/Resources/AppIcon_1024.png" "${RESOURCES_DIR}/AppIcon_1024.png"
fi

chmod 755 "${MACOS_DIR}/ClaudeAccountManager"

codesign --force --deep --sign - "${APP_DIR}"

# Invalidate Finder / LaunchServices icon cache
touch "${APP_DIR}"
if [ -f "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]; then
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${APP_DIR}" 2>/dev/null || true
fi

echo "Built: ${APP_DIR}"
