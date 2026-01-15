#!/bin/bash

# Flutter Play Store Deployment Script
# Generic script for deploying Flutter apps to Google Play Store
#
# Usage:
#   ./deploy.sh [options]
#
# Options:
#   --setup          Run initial setup (keystore generation)
#   --build          Build release app bundle
#   --build-apk      Build release APK for testing
#   --validate       Validate keystore configuration
#   --version        Show current version
#   --version-bump   Bump version number
#   --clean          Clean build artifacts
#   --help           Show this help message

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_PROJECT_DIR="${FLUTTER_PROJECT_DIR:-$(pwd)}"
ANDROID_DIR="$FLUTTER_PROJECT_DIR/android"
KEYSTORE_DIR="$ANDROID_DIR/keystore"
KEYSTORE_FILE="$KEYSTORE_DIR/app-release.jks"
KEYSTORE_PROPERTIES="$ANDROID_DIR/keystore.properties"
KEYSTORE_TEMPLATE="$ANDROID_DIR/keystore.properties.template"

# Functions
show_help() {
    cat << EOF
${BLUE}Flutter Play Store Deployment Script${NC}

Usage: $0 [options]

Options:
  --setup          Run initial setup (keystore generation)
  --build          Build release app bundle (AAB) for Play Store
  --build-apk      Build release APK for testing
  --validate       Validate keystore configuration
  --version        Show current version
  --version-bump   Bump version number interactively
  --clean          Clean build artifacts
  --help           Show this help message

Environment Variables:
  FLUTTER_PROJECT_DIR  - Flutter project directory (default: current directory)

Examples:
  $0 --setup              # Initial setup
  $0 --build              # Build release bundle
  $0 --version-bump       # Bump version
  $0 --validate --build   # Validate and build
EOF
}

check_environment() {
    echo -e "${BLUE}Checking environment...${NC}"
    
    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}❌ Flutter is not installed or not in PATH${NC}"
        exit 1
    fi
    
    if ! command -v keytool &> /dev/null; then
        echo -e "${RED}❌ keytool is not installed (part of JDK)${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Environment check passed${NC}"
}

setup_keystore() {
    check_environment
    
    echo -e "${BLUE}Setting up keystore for Play Store deployment...${NC}"
    
    if [ -f "$KEYSTORE_FILE" ]; then
        echo -e "${YELLOW}⚠️  Keystore already exists at $KEYSTORE_FILE${NC}"
        echo -e "${YELLOW}   Skipping keystore generation.${NC}"
    else
        mkdir -p "$KEYSTORE_DIR"
        echo -e "${YELLOW}Generating keystore...${NC}"
        keytool -genkey -v \
            -keystore "$KEYSTORE_FILE" \
            -keyalg RSA \
            -keysize 2048 \
            -validity 10000 \
            -alias app-release
        
        echo -e "${GREEN}✅ Keystore generated at $KEYSTORE_FILE${NC}"
    fi
    
    if [ ! -f "$KEYSTORE_PROPERTIES" ]; then
        if [ -f "$KEYSTORE_TEMPLATE" ]; then
            cp "$KEYSTORE_TEMPLATE" "$KEYSTORE_PROPERTIES"
            echo -e "${YELLOW}⚠️  Please edit $KEYSTORE_PROPERTIES with your keystore details${NC}"
        else
            echo -e "${YELLOW}⚠️  Creating keystore.properties template...${NC}"
            cat > "$KEYSTORE_PROPERTIES" << EOF
# Keystore properties for release signing
# DO NOT commit this file to version control

storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=app-release
storeFile=keystore/app-release.jks
EOF
            echo -e "${YELLOW}⚠️  Please edit $KEYSTORE_PROPERTIES with your keystore details${NC}"
        fi
    fi
}

validate_keystore() {
    echo -e "${BLUE}Validating keystore configuration...${NC}"
    
    if [ ! -f "$KEYSTORE_PROPERTIES" ]; then
        echo -e "${RED}❌ keystore.properties not found${NC}"
        echo -e "${YELLOW}   Run '$0 --setup' first${NC}"
        exit 1
    fi
    
    if [ ! -f "$KEYSTORE_FILE" ]; then
        echo -e "${RED}❌ Keystore file not found${NC}"
        echo -e "${YELLOW}   Expected: $KEYSTORE_FILE${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Keystore configuration valid${NC}"
}

show_version() {
    echo -e "${BLUE}Current version:${NC}"
    cd "$FLUTTER_PROJECT_DIR"
    if grep -q "^version:" pubspec.yaml; then
        grep "^version:" pubspec.yaml | sed 's/version: //'
    else
        echo -e "${RED}Version not found in pubspec.yaml${NC}"
    fi
}

bump_version() {
    echo -e "${BLUE}Bumping version...${NC}"
    cd "$FLUTTER_PROJECT_DIR"
    
    CURRENT_VERSION=$(grep -E "^version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
    CURRENT_BUILD=$(grep -E "^version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f2)
    
    echo -e "${YELLOW}Current version: $CURRENT_VERSION+$CURRENT_BUILD${NC}"
    read -p "New version name (e.g., 1.0.1): " NEW_VERSION
    
    NEW_BUILD=$((CURRENT_BUILD + 1))
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^version: .*/version: $NEW_VERSION+$NEW_BUILD/" pubspec.yaml
    else
        # Linux
        sed -i "s/^version: .*/version: $NEW_VERSION+$NEW_BUILD/" pubspec.yaml
    fi
    
    echo -e "${GREEN}✅ Version updated to $NEW_VERSION+$NEW_BUILD${NC}"
}

clean_build() {
    echo -e "${BLUE}Cleaning build artifacts...${NC}"
    cd "$FLUTTER_PROJECT_DIR"
    flutter clean
    echo -e "${GREEN}✅ Clean complete${NC}"
}

build_aab() {
    check_environment
    validate_keystore
    
    echo -e "${BLUE}Building release app bundle...${NC}"
    cd "$FLUTTER_PROJECT_DIR"
    
    flutter clean
    flutter pub get
    flutter build appbundle --release
    
    BUILD_OUTPUT="$FLUTTER_PROJECT_DIR/build/app/outputs/bundle/release/app-release.aab"
    
    if [ -f "$BUILD_OUTPUT" ]; then
        echo -e "${GREEN}✅ Build successful!${NC}"
        echo -e "${GREEN}   AAB file: $BUILD_OUTPUT${NC}"
        ls -lh "$BUILD_OUTPUT"
    else
        echo -e "${RED}❌ Build failed - AAB file not found${NC}"
        exit 1
    fi
}

build_apk() {
    check_environment
    validate_keystore
    
    echo -e "${BLUE}Building release APK...${NC}"
    cd "$FLUTTER_PROJECT_DIR"
    
    flutter clean
    flutter pub get
    flutter build apk --release
    
    BUILD_OUTPUT="$FLUTTER_PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
    
    if [ -f "$BUILD_OUTPUT" ]; then
        echo -e "${GREEN}✅ Build successful!${NC}"
        echo -e "${GREEN}   APK file: $BUILD_OUTPUT${NC}"
        ls -lh "$BUILD_OUTPUT"
    else
        echo -e "${RED}❌ Build failed - APK file not found${NC}"
        exit 1
    fi
}

# Main script
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --setup)
            setup_keystore
            shift
            ;;
        --build)
            build_aab
            shift
            ;;
        --build-apk)
            build_apk
            shift
            ;;
        --validate)
            validate_keystore
            shift
            ;;
        --version)
            show_version
            shift
            ;;
        --version-bump)
            bump_version
            shift
            ;;
        --clean)
            clean_build
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

