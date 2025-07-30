#!/bin/bash

# Analog Film Plugin Uninstaller
# Removes the FxPlug4 plugin from Final Cut Pro

set -e

PROJECT_NAME="AnalogFilmPlugin"
PLUGIN_BUNDLE="${PROJECT_NAME}.bundle"
INSTALL_DIR="$HOME/Library/Plug-Ins/FxPlug"
INSTALLED_BUNDLE="$INSTALL_DIR/$PLUGIN_BUNDLE"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🗑️  Uninstalling Analog Film Plugin${NC}"
echo "====================================="

# Check if plugin is installed
if [[ ! -d "$INSTALLED_BUNDLE" ]]; then
    echo -e "${YELLOW}⚠️  Plugin not found at: $INSTALLED_BUNDLE${NC}"
    echo "The plugin may not be installed or may have been removed already."
    exit 0
fi

# Confirm uninstallation
echo -e "${YELLOW}❓ Are you sure you want to uninstall the Analog Film Plugin?${NC}"
echo "This will remove: $INSTALLED_BUNDLE"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}ℹ️  Uninstallation cancelled.${NC}"
    exit 0
fi

# Remove plugin bundle
echo -e "${YELLOW}🗑️  Removing plugin bundle...${NC}"
rm -rf "$INSTALLED_BUNDLE"

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Plugin uninstalled successfully!${NC}"
else
    echo -e "${RED}❌ Uninstallation failed!${NC}"
    exit 1
fi

# Verify removal
if [[ ! -d "$INSTALLED_BUNDLE" ]]; then
    echo -e "${GREEN}✅ Plugin bundle removed from: $INSTALL_DIR${NC}"
else
    echo -e "${RED}❌ Plugin bundle still exists. Manual removal may be required.${NC}"
    exit 1
fi

# Final instructions
echo ""
echo -e "${BLUE}🎬 Next Steps:${NC}"
echo "1. Restart Final Cut Pro if it's currently running"
echo "2. The Analog Film Plugin will no longer appear in the Effects menu"
echo "3. Any existing projects using the plugin will show a missing effect warning"
echo ""

echo -e "${GREEN}🎉 Uninstallation completed successfully!${NC}"
echo "The Analog Film Plugin has been removed from Final Cut Pro."