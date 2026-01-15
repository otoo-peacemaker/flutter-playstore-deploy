# Flutter Play Store Deployment Makefile
# Generic Makefile for deploying Flutter apps to Google Play Store
# 
# Usage:
#   make help              - Show this help message
#   make setup             - Initial setup (keystore generation)
#   make build             - Build release app bundle
#   make build-apk         - Build release APK (for testing)
#   make clean             - Clean build artifacts
#   make version           - Show current version
#   make version-bump       - Bump version number
#   make validate          - Validate keystore configuration
#   make deploy            - Full deployment (build + validate)

.PHONY: help setup build build-apk clean version version-bump validate deploy check-env

# Configuration
FLUTTER_PROJECT_DIR ?= $(shell pwd)
ANDROID_DIR = $(FLUTTER_PROJECT_DIR)/android
KEYSTORE_DIR = $(ANDROID_DIR)/keystore
KEYSTORE_FILE = $(KEYSTORE_DIR)/app-release.jks
KEYSTORE_PROPERTIES = $(ANDROID_DIR)/keystore.properties
KEYSTORE_TEMPLATE = $(ANDROID_DIR)/keystore.properties.template
BUILD_OUTPUT_AAB = $(FLUTTER_PROJECT_DIR)/build/app/outputs/bundle/release/app-release.aab
BUILD_OUTPUT_APK = $(FLUTTER_PROJECT_DIR)/build/app/outputs/flutter-apk/app-release.apk

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Flutter Play Store Deployment$(NC)"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Environment variables:"
	@echo "  FLUTTER_PROJECT_DIR  - Flutter project directory (default: current directory)"
	@echo ""

check-env: ## Check if Flutter and required tools are installed
	@echo "$(BLUE)Checking environment...$(NC)"
	@command -v flutter >/dev/null 2>&1 || { echo "$(RED)❌ Flutter is not installed$(NC)"; exit 1; }
	@command -v keytool >/dev/null 2>&1 || { echo "$(RED)❌ keytool is not installed (part of JDK)$(NC)"; exit 1; }
	@echo "$(GREEN)✅ Environment check passed$(NC)"

setup: check-env ## Initial setup - generate keystore
	@echo "$(BLUE)Setting up keystore for Play Store deployment...$(NC)"
	@if [ -f "$(KEYSTORE_FILE)" ]; then \
		echo "$(YELLOW)⚠️  Keystore already exists at $(KEYSTORE_FILE)$(NC)"; \
		echo "$(YELLOW)   Skipping keystore generation.$(NC)"; \
	else \
		mkdir -p $(KEYSTORE_DIR); \
		echo "$(YELLOW)Generating keystore...$(NC)"; \
		keytool -genkey -v \
			-keystore $(KEYSTORE_FILE) \
			-keyalg RSA \
			-keysize 2048 \
			-validity 10000 \
			-alias app-release; \
		echo "$(GREEN)✅ Keystore generated at $(KEYSTORE_FILE)$(NC)"; \
	fi
	@if [ ! -f "$(KEYSTORE_PROPERTIES)" ]; then \
		if [ -f "$(KEYSTORE_TEMPLATE)" ]; then \
			cp $(KEYSTORE_TEMPLATE) $(KEYSTORE_PROPERTIES); \
			echo "$(YELLOW)⚠️  Please edit $(KEYSTORE_PROPERTIES) with your keystore details$(NC)"; \
		else \
			echo "$(YELLOW)⚠️  Creating keystore.properties template...$(NC)"; \
			echo "storePassword=YOUR_KEYSTORE_PASSWORD" > $(KEYSTORE_PROPERTIES); \
			echo "keyPassword=YOUR_KEY_PASSWORD" >> $(KEYSTORE_PROPERTIES); \
			echo "keyAlias=app-release" >> $(KEYSTORE_PROPERTIES); \
			echo "storeFile=keystore/app-release.jks" >> $(KEYSTORE_PROPERTIES); \
			echo "$(YELLOW)⚠️  Please edit $(KEYSTORE_PROPERTIES) with your keystore details$(NC)"; \
		fi; \
	fi

validate: check-env ## Validate keystore configuration
	@echo "$(BLUE)Validating keystore configuration...$(NC)"
	@if [ ! -f "$(KEYSTORE_PROPERTIES)" ]; then \
		echo "$(RED)❌ keystore.properties not found$(NC)"; \
		echo "$(YELLOW)   Run 'make setup' first$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f "$(KEYSTORE_FILE)" ]; then \
		echo "$(RED)❌ Keystore file not found$(NC)"; \
		echo "$(YELLOW)   Expected: $(KEYSTORE_FILE)$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✅ Keystore configuration valid$(NC)"

version: ## Show current app version
	@echo "$(BLUE)Current version:$(NC)"
	@cd $(FLUTTER_PROJECT_DIR) && \
		grep -E "^version:" pubspec.yaml | sed 's/version: //' || echo "$(RED)Version not found$(NC)"

version-bump: ## Bump version number (interactive)
	@echo "$(BLUE)Bumping version...$(NC)"
	@cd $(FLUTTER_PROJECT_DIR) && \
		CURRENT_VERSION=$$(grep -E "^version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f1) && \
		CURRENT_BUILD=$$(grep -E "^version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f2) && \
		echo "$(YELLOW)Current version: $$CURRENT_VERSION+$$CURRENT_BUILD$(NC)" && \
		read -p "New version name (e.g., 1.0.1): " NEW_VERSION && \
		NEW_BUILD=$$((CURRENT_BUILD + 1)) && \
		sed -i '' "s/^version: .*/version: $$NEW_VERSION+$$NEW_BUILD/" pubspec.yaml && \
		echo "$(GREEN)✅ Version updated to $$NEW_VERSION+$$NEW_BUILD$(NC)"

clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@cd $(FLUTTER_PROJECT_DIR) && flutter clean
	@echo "$(GREEN)✅ Clean complete$(NC)"

build: check-env validate ## Build release app bundle (AAB) for Play Store
	@echo "$(BLUE)Building release app bundle...$(NC)"
	@cd $(FLUTTER_PROJECT_DIR) && \
		flutter clean && \
		flutter pub get && \
		flutter build appbundle --release
	@if [ -f "$(BUILD_OUTPUT_AAB)" ]; then \
		echo "$(GREEN)✅ Build successful!$(NC)"; \
		echo "$(GREEN)   AAB file: $(BUILD_OUTPUT_AAB)$(NC)"; \
		ls -lh $(BUILD_OUTPUT_AAB); \
	else \
		echo "$(RED)❌ Build failed - AAB file not found$(NC)"; \
		exit 1; \
	fi

build-apk: check-env validate ## Build release APK for testing
	@echo "$(BLUE)Building release APK...$(NC)"
	@cd $(FLUTTER_PROJECT_DIR) && \
		flutter clean && \
		flutter pub get && \
		flutter build apk --release
	@if [ -f "$(BUILD_OUTPUT_APK)" ]; then \
		echo "$(GREEN)✅ Build successful!$(NC)"; \
		echo "$(GREEN)   APK file: $(BUILD_OUTPUT_APK)$(NC)"; \
		ls -lh $(BUILD_OUTPUT_APK); \
	else \
		echo "$(RED)❌ Build failed - APK file not found$(NC)"; \
		exit 1; \
	fi

deploy: build ## Full deployment workflow (validate + build)
	@echo "$(GREEN)✅ Deployment package ready!$(NC)"
	@echo ""
	@echo "$(BLUE)Next steps:$(NC)"
	@echo "  1. Upload $(BUILD_OUTPUT_AAB) to Google Play Console"
	@echo "  2. Complete store listing information"
	@echo "  3. Submit for review"
	@echo ""

info: ## Show project information
	@echo "$(BLUE)Project Information:$(NC)"
	@echo "  Project Directory: $(FLUTTER_PROJECT_DIR)"
	@echo "  Android Directory: $(ANDROID_DIR)"
	@echo "  Keystore: $(KEYSTORE_FILE)"
	@echo "  Build Output (AAB): $(BUILD_OUTPUT_AAB)"
	@echo "  Build Output (APK): $(BUILD_OUTPUT_APK)"
	@echo ""
	@$(MAKE) version

