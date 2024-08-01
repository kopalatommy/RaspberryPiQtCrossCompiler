#!/bin/bash

# Values for coloring output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

QtMajorVersion="$1"
QtMinorVersion="$2"
QtPatchVersion="$3"
QtVersion="$QtMajorVersion.$QtMinorVersion.$QtPatchVersion"

BUILD_LOC=$4
SOURCE_CACHE_LOC=$5

# Get the number of threads to speed up the compilation
threads=$(nproc)

# Log that starts the script
echo -e "${GREEN}Starting Qt Host Build${NC}"

# Build Qt for host
echo -e "${GREEN}Building Qt for Host${NC}"
cd $BUILD_LOC/host-build/
cmake $SOURCE_CACHE_LOC/qt-everywhere-src-${QtMajorVersion}.${QtMinorVersion}.${QtPatchVersion}/ -GNinja -DCMAKE_BUILD_TYPE=Release -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF -DCMAKE_INSTALL_PREFIX=${BUILD_LOC}/host -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
cmake --build . --parallel $threads
cmake --install .
