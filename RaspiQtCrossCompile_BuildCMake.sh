#!/bin/bash

# Values for coloring output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

threads=$(nproc)

BUILD_LOC=$1
SOURCE_CACHE_LOC=$2

echo -e "${GREEN}Starting build CMake${NC}"
echo -e "Build Loc: ${BUILD_LOC}"

# Check if CMake exists
if command -v cmake &> /dev/null
then
    echo -e "${GREEN}CMake is already installed${NC}"
    exit 0
fi

# Download source files
cd $BUILD_LOC
# Delete old version if exists
if [ -d CMake ]; then
    echo -e "${GREEN}Deleting old CMake source${NC}"
    rm -rf CMake
fi

cd ${SOURCE_CACHE_LOC}
if [ ! -d CMake ]; then
    # Download source
    git clone https://github.com/Kitware/CMake.git
else
    cd ${SOURCE_CACHE_LOC}/CMake
    # git stash
fi

cd ${BUILD_LOC}
mkdir CMake

# Build source
cd CMake
${SOURCE_CACHE_LOC}/CMake/bootstrap && make -j${threads} -s && sudo make install

if [ $? -eq 0 ]; then
    echo -e "#{GREEN}Successfully built CMake${NC}"
    exit 0
else
    echo -e "${RED}Failed to build CMake${NC}"
    exit 1
fi