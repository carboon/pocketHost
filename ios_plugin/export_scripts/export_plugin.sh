#!/bin/bash

# Define constants
PLUGIN_NAME="PocketHostPlugin"
XCFRAMEWORK_DIR="./bin"
BUILD_DIR="./build"

# Clean up previous builds
rm -rf "$XCFRAMEWORK_DIR" "$BUILD_DIR"

# Create build directories
mkdir -p "$XCFRAMEWORK_DIR" "$BUILD_DIR"

echo "Building for iOS Device (iphoneos)..."
xcodebuild archive \
  -scheme "$PLUGIN_NAME" \
  -destination "generic/platform=iOS" \
  -archivePath "$BUILD_DIR/$PLUGIN_NAME-iOS" \
  -sdk iphoneos \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  SKIP_INSTALL=NO \
  -derivedDataPath "$BUILD_DIR/DerivedData"
  
if [ $? -ne 0 ]; then
    echo "iOS Device build failed."
    exit 1
fi

echo "Building for iOS Simulator (iphonesimulator)..."
xcodebuild archive \
  -scheme "$PLUGIN_NAME" \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "$BUILD_DIR/$PLUGIN_NAME-Simulator" \
  -sdk iphonesimulator \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  SKIP_INSTALL=NO \
  -derivedDataPath "$BUILD_DIR/DerivedData"

if [ $? -ne 0 ]; then
    echo "iOS Simulator build failed."
    exit 1
fi

echo "Creating XCFramework..."
xcodebuild -create-xcframework \
  -framework "$BUILD_DIR/$PLUGIN_NAME-iOS.xcarchive/Products/Library/Frameworks/$PLUGIN_NAME.framework" \
  -framework "$BUILD_DIR/$PLUGIN_NAME-Simulator.xcarchive/Products/Library/Frameworks/$PLUGIN_NAME.framework" \
  -output "$XCFRAMEWORK_DIR/$PLUGIN_NAME.xcframework"

if [ $? -ne 0 ]; then
    echo "XCFramework creation failed."
    exit 1
fi

echo "Successfully built $PLUGIN_NAME.xcframework"

# Godot expects the xcframework in `res://ios_plugin/bin/`.
# No further steps required for this script, as it builds into `ios_plugin/bin/` directly.
