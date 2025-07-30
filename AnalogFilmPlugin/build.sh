#!/bin/bash

# Analog Film Plugin Build Script
# Builds the FxPlug4 plugin for Final Cut Pro on Apple Silicon

set -e

PROJECT_NAME="AnalogFilmPlugin"
PROJECT_FILE="${PROJECT_NAME}.xcodeproj"
TARGET_NAME="${PROJECT_NAME}"
CONFIGURATION="Release"
ARCH="arm64"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎬 Building Analog Film Plugin for Final Cut Pro${NC}"
echo "=================================================="

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Error: Xcode is not installed or xcodebuild is not in PATH${NC}"
    exit 1
fi

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ Error: This plugin can only be built on macOS${NC}"
    exit 1
fi

# Check for Apple Silicon
SYSTEM_ARCH=$(uname -m)
if [[ "$SYSTEM_ARCH" != "arm64" ]]; then
    echo -e "${YELLOW}⚠️  Warning: Building on non-Apple Silicon Mac. Plugin will only work on M1/M2/M3 Macs${NC}"
fi

# Check if project file exists
if [[ ! -d "$PROJECT_FILE" ]]; then
    echo -e "${RED}❌ Error: Project file $PROJECT_FILE not found${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Build Configuration:${NC}"
echo "  Project: $PROJECT_NAME"
echo "  Target: $TARGET_NAME"
echo "  Configuration: $CONFIGURATION"
echo "  Architecture: $ARCH"
echo "  macOS Deployment Target: 11.0"
echo ""

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
xcodebuild -project "$PROJECT_FILE" -target "$TARGET_NAME" -configuration "$CONFIGURATION" clean

# Build the plugin
echo -e "${YELLOW}🔨 Building plugin...${NC}"
xcodebuild \
    -project "$PROJECT_FILE" \
    -target "$TARGET_NAME" \
    -configuration "$CONFIGURATION" \
    ARCHS="$ARCH" \
    VALID_ARCHS="$ARCH" \
    ONLY_ACTIVE_ARCH=YES \
    build

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Build completed successfully!${NC}"
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

# Find the built bundle
BUILD_DIR="build/$CONFIGURATION"
PLUGIN_BUNDLE="${BUILD_DIR}/${PROJECT_NAME}.bundle"

if [[ -d "$PLUGIN_BUNDLE" ]]; then
    echo -e "${GREEN}📦 Plugin bundle created: $PLUGIN_BUNDLE${NC}"
    
    # Show bundle info
    echo -e "${BLUE}📋 Bundle Information:${NC}"
    ls -la "$PLUGIN_BUNDLE"
    
    # Check code signing
    echo -e "${BLUE}🔐 Code Signing Status:${NC}"
    codesign -dv "$PLUGIN_BUNDLE" 2>&1 || echo "Bundle is not code signed"
    
    # Installation instructions
    echo ""
    echo -e "${BLUE}📥 Installation Instructions:${NC}"
    echo "1. Copy the plugin bundle to Final Cut Pro's plugin directory:"
    echo "   cp -R \"$PLUGIN_BUNDLE\" \"~/Library/Plug-Ins/FxPlug/\""
    echo ""
    echo "2. Restart Final Cut Pro"
    echo ""
    echo "3. The plugin will appear under: Effects > Color > Film Emulation"
    echo ""
    
    # Code signing instructions
    echo -e "${BLUE}🔐 Code Signing (Optional):${NC}"
    echo "For distribution, sign the plugin with your Developer ID:"
    echo "  codesign --deep --force --verify --verbose --sign \"Developer ID Application: Your Name\" \"$PLUGIN_BUNDLE\""
    echo ""
    echo "For notarization:"
    echo "  xcrun notarytool submit \"$PLUGIN_BUNDLE\" --keychain-profile \"YourProfile\" --wait"
    echo ""
    
else
    echo -e "${RED}❌ Plugin bundle not found at expected location: $PLUGIN_BUNDLE${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Analog Film Plugin build completed successfully!${NC}"