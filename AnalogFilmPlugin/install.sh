#!/bin/bash

# Analog Film Plugin Installation Script
# Installs the FxPlug4 plugin to Final Cut Pro

set -e

PROJECT_NAME="AnalogFilmPlugin"
PLUGIN_BUNDLE="${PROJECT_NAME}.bundle"
BUILD_DIR="build/Release"
SOURCE_BUNDLE="${BUILD_DIR}/${PLUGIN_BUNDLE}"
INSTALL_DIR="$HOME/Library/Plug-Ins/FxPlug"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📥 Installing Analog Film Plugin${NC}"
echo "=================================="

# Check if source bundle exists
if [[ ! -d "$SOURCE_BUNDLE" ]]; then
    echo -e "${RED}❌ Error: Plugin bundle not found at $SOURCE_BUNDLE${NC}"
    echo "Please build the plugin first by running: ./build.sh"
    exit 1
fi

# Create FxPlug directory if it doesn't exist
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo -e "${YELLOW}📁 Creating FxPlug directory: $INSTALL_DIR${NC}"
    mkdir -p "$INSTALL_DIR"
fi

# Check if plugin is already installed
INSTALLED_BUNDLE="$INSTALL_DIR/$PLUGIN_BUNDLE"
if [[ -d "$INSTALLED_BUNDLE" ]]; then
    echo -e "${YELLOW}⚠️  Plugin is already installed. Removing old version...${NC}"
    rm -rf "$INSTALLED_BUNDLE"
fi

# Copy plugin bundle
echo -e "${YELLOW}📦 Installing plugin bundle...${NC}"
cp -R "$SOURCE_BUNDLE" "$INSTALL_DIR/"

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Plugin installed successfully!${NC}"
else
    echo -e "${RED}❌ Installation failed!${NC}"
    exit 1
fi

# Verify installation
if [[ -d "$INSTALLED_BUNDLE" ]]; then
    echo -e "${GREEN}📍 Plugin installed at: $INSTALLED_BUNDLE${NC}"
    
    # Show permissions
    echo -e "${BLUE}📋 Plugin Permissions:${NC}"
    ls -la "$INSTALLED_BUNDLE"
    
    # Check bundle structure
    echo -e "${BLUE}📋 Bundle Contents:${NC}"
    find "$INSTALLED_BUNDLE" -name "*.dylib" -o -name "Info.plist" | head -10
    
else
    echo -e "${RED}❌ Installation verification failed!${NC}"
    exit 1
fi

# Final instructions
echo ""
echo -e "${BLUE}🎬 Next Steps:${NC}"
echo "1. Restart Final Cut Pro if it's currently running"
echo "2. Create a new project or open an existing one"
echo "3. Apply the effect from: Effects > Color > Film Emulation"
echo "4. Choose your favorite film stock and adjust parameters"
echo ""

echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
echo "The Analog Film Plugin is now ready to use in Final Cut Pro."