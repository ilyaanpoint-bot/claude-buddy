#!/bin/sh
# Builds ./ClaudeBuddy from src/ (for development; use install.sh to install).
cd "$(dirname "$0")" && swiftc -O -swift-version 5 src/*.swift -o ClaudeBuddy
