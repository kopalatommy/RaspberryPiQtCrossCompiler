#!/bin/bash

# Values for coloring output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

threads=$(nproc)

echo -e "${GREEN}Starting build CMake${CN}"

# Check if CMake exists
if command -v cmake &> /dev/null
then
    echo -e "${GREEN}CMake is already installed${NC}"
    exit 0
fi

# Download source files
cd ~
# Delete old version if exists
if [ -d CMake ]; then
    echo -e "${GREEN}Deleting old CMake source${NC}"
    rm -rf CMake
fi

# Download source
git clone https://github.com/Kitware/CMake.git
# Build source
cd CMake
./bootstrap && make -j${threads} -s && sudo make install

if [ $? -eq 0 ];
    echo -e "#{GREEN}Successfully built CMake${NC}"
    exit 0
else
    echo -e "${RED}Failed to build CMake${NC}"
    exit 1
fi