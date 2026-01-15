# Flutter Play Store Deployment Tools

Generic scripts and Makefile for deploying Flutter apps to Google Play Store. These tools can be used with any Flutter project.

## Features

- ✅ Keystore generation and management
- ✅ Release build automation (AAB and APK)
- ✅ Version management
- ✅ Configuration validation
- ✅ Environment checks
- ✅ Cross-platform support (macOS, Linux)

## Quick Start

### Option 1: Using Makefile

1. Copy the `Makefile` to your Flutter project root
2. Run setup:

   ```bash
   make setup
   ```

3. Edit `android/keystore.properties` with your keystore passwords
4. Build release bundle:

   ```bash
   make build
   ```

### Option 2: Using Shell Script

1. Copy `deploy.sh` to your Flutter project root
2. Make it executable:

   ```bash
   chmod +x deploy.sh
   ```

3. Run setup:

   ```bash
   ./deploy.sh --setup
   ```

4. Edit `android/keystore.properties` with your keystore passwords
5. Build release bundle:

   ```bash
   ./deploy.sh --build
   ```

## Available Commands

### Makefile Commands

```bash
make help          # Show help message
make setup         # Initial setup (keystore generation)
make build         # Build release app bundle (AAB)
make build-apk     # Build release APK (for testing)
make validate      # Validate keystore configuration
make version       # Show current version
make version-bump  # Bump version number
make clean         # Clean build artifacts
make deploy       # Full deployment (validate + build)
make info         # Show project information
```

### Shell Script Commands

```bash
./deploy.sh --setup          # Initial setup
./deploy.sh --build          # Build release bundle
./deploy.sh --build-apk     # Build release APK
./deploy.sh --validate      # Validate configuration
./deploy.sh --version       # Show current version
./deploy.sh --version-bump  # Bump version
./deploy.sh --clean         # Clean build artifacts
./deploy.sh --help          # Show help
```

## Setup Instructions

### 1. Initial Setup

Run the setup command to generate a keystore:

```bash
make setup
# or
./deploy.sh --setup
```

This will:

- Generate a keystore file at `android/keystore/app-release.jks`
- Create `android/keystore.properties` template

### 2. Configure Keystore Properties

Edit `android/keystore.properties` with your actual keystore details:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=app-release
storeFile=keystore/app-release.jks
```

**Important**: Never commit `keystore.properties` or `.jks` files to version control!

### 3. Update build.gradle.kts

Ensure your `android/app/build.gradle.kts` has the signing configuration. Here's a template:

```kotlin
import java.util.Properties
import java.io.FileInputStream

android {
    // ... other config ...
    
    signingConfigs {
        create("release") {
            val keystorePropertiesFile = rootProject.file("keystore.properties")
            if (keystorePropertiesFile.exists()) {
                val keystoreProperties = Properties()
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))
                
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    
    buildTypes {
        release {
            signingConfig = if (signingConfigs.findByName("release") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}
```

## Usage Examples

### Build for Play Store

```bash
# Validate configuration first
make validate

# Build release bundle
make build

# The AAB file will be at:
# build/app/outputs/bundle/release/app-release.aab
```

### Update Version

```bash
# Show current version
make version

# Bump version interactively
make version-bump
```

### Full Deployment Workflow

```bash
# 1. Clean previous builds
make clean

# 2. Bump version
make version-bump

# 3. Build release bundle
make build

# 4. Upload to Play Console
# (manual step - upload the AAB file)
```

## File Structure

After setup, your project should have:

```
your-flutter-app/
├── android/
│   ├── keystore/
│   │   └── app-release.jks      # Keystore file (DO NOT COMMIT)
│   ├── keystore.properties      # Keystore config (DO NOT COMMIT)
│   └── app/
│       └── build.gradle.kts    # With signing config
├── Makefile                     # (optional - if using Makefile)
├── deploy.sh                    # (optional - if using script)
└── pubspec.yaml                 # With version info
```

## Environment Variables

- `FLUTTER_PROJECT_DIR`: Flutter project directory (default: current directory)

Example:

```bash
FLUTTER_PROJECT_DIR=/path/to/your/app make build
```

## Troubleshooting

### Keystore Not Found

If you get "keystore file not found" error:

1. Ensure the keystore exists at `android/keystore/app-release.jks`
2. Check the path in `keystore.properties` matches your setup
3. Run `make validate` to check configuration

### Build Fails

1. Ensure Flutter is installed: `flutter --version`
2. Ensure JDK is installed: `keytool -help`
3. Clean and rebuild: `make clean && make build`

### Version Bump Issues

If version bump doesn't work:

- Check `pubspec.yaml` has a `version:` line
- Format should be: `version: 1.0.0+1`

## Security Notes

⚠️ **IMPORTANT**: 

- Never commit keystore files (`.jks`, `.keystore`) to version control
- Never commit `keystore.properties` to version control
- Store keystore backups securely
- Use different keystores for different apps
- Consider using Google Play App Signing for additional security

Add to `.gitignore`:

```
**/keystore.properties
*.jks
*.keystore
android/keystore/
```

## Integration with CI/CD

You can use these scripts in CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Build Release
  run: |
    make validate
    make build
  env:
    FLUTTER_PROJECT_DIR: ${{ github.workspace }}
```

## License

These scripts are provided as-is for use with any Flutter project.

