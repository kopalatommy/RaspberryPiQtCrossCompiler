#!/bin/bash

# Values for coloring output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Get the number of cores to speed up the compilation
CORES=$(nproc)

# Log that starts the script
echo -e "${GREEN}Starting Qt Host Build${NC}"

