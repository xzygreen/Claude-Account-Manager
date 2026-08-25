#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
SDK_PATH="${MACOS_SDK_OVERRIDE:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}"
MODULE_CACHE_DIR="${PROJECT_DIR}/.build/ModuleCache"
TESTING_PLUGIN="/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"

mkdir -p "${MODULE_CACHE_DIR}"
export SDKROOT="${SDK_PATH}"
export CLANG_MODULE_CACHE_PATH="${MODULE_CACHE_DIR}"
export SWIFTPM_MODULECACHE_OVERRIDE="${MODULE_CACHE_DIR}"
export DYLD_FRAMEWORK_PATH="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
export DYLD_LIBRARY_PATH="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

swift test --disable-sandbox \
  -Xswiftc -load-plugin-library \
  -Xswiftc "${TESTING_PLUGIN}"
