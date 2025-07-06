#!/bin/bash

# Build script for macOS Swift utilities
# This script compiles the Swift utilities for both Intel and Apple Silicon

set -e

echo "Building macOS utilities for WoW Recorder..."

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This script must be run on macOS"
    exit 1
fi

# Check if Swift is available
if ! command -v swiftc &> /dev/null; then
    echo "Error: Swift compiler not found. Please install Xcode or Xcode Command Line Tools."
    exit 1
fi

# Check macOS version for ScreenCaptureKit support
os_version=$(sw_vers -productVersion)
major_version=$(echo $os_version | cut -d. -f1)
minor_version=$(echo $os_version | cut -d. -f2)

if [[ $major_version -lt 12 ]] || [[ $major_version -eq 12 && $minor_version -lt 3 ]]; then
    echo "Warning: ScreenCaptureKit requires macOS 12.3 or later. Current version: $os_version"
    echo "The screen-capture utility may not work properly on this system."
fi

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building in directory: $SCRIPT_DIR"

# Function to build a Swift file for multiple architectures
build_universal() {
    local source_file=$1
    local output_name=$2
    
    echo "Building $output_name..."
    
    # Build for x86_64 (Intel)
    echo "  - Building for Intel (x86_64)..."
    swiftc -target x86_64-apple-macos12.0 -o "${output_name}-x64" "$source_file" 2>/dev/null || {
        echo "    Warning: Intel build failed, trying without target specification..."
        swiftc -o "${output_name}-x64" "$source_file" || {
            echo "    Error: Failed to build for Intel"
            return 1
        }
    }
    
    # Build for arm64 (Apple Silicon)
    echo "  - Building for Apple Silicon (arm64)..."
    swiftc -target arm64-apple-macos12.0 -o "${output_name}-arm64" "$source_file" 2>/dev/null || {
        echo "    Warning: Apple Silicon build failed, trying without target specification..."
        swiftc -o "${output_name}-arm64" "$source_file" || {
            echo "    Error: Failed to build for Apple Silicon"
            return 1
        }
    }
    
    # Create universal binary
    echo "  - Creating universal binary..."
    if [[ -f "${output_name}-x64" && -f "${output_name}-arm64" ]]; then
        lipo -create "${output_name}-x64" "${output_name}-arm64" -output "$output_name" && {
            echo "  - Successfully created universal binary: $output_name"
            # Clean up individual architecture binaries
            rm -f "${output_name}-x64" "${output_name}-arm64"
        } || {
            echo "  - Warning: Failed to create universal binary, keeping x64 version"
            if [[ -f "${output_name}-x64" ]]; then
                mv "${output_name}-x64" "$output_name"
                rm -f "${output_name}-arm64"
            else
                mv "${output_name}-arm64" "$output_name"
            fi
        }
    elif [[ -f "${output_name}-x64" ]]; then
        mv "${output_name}-x64" "$output_name"
        echo "  - Using Intel-only binary"
    elif [[ -f "${output_name}-arm64" ]]; then
        mv "${output_name}-arm64" "$output_name"
        echo "  - Using Apple Silicon-only binary"
    else
        echo "  - Error: No binaries were created"
        return 1
    fi
    
    # Make executable
    chmod +x "$output_name"
    
    return 0
}

# Build WoW detector
if [[ -f "wow-detector.swift" ]]; then
    build_universal "wow-detector.swift" "wow-detector"
else
    echo "Error: wow-detector.swift not found"
    exit 1
fi

# Build screen capture utility
if [[ -f "screen-capture.swift" ]]; then
    build_universal "screen-capture.swift" "screen-capture"
else
    echo "Error: screen-capture.swift not found"
    exit 1
fi

echo ""
echo "Build completed successfully!"
echo ""
echo "Created binaries:"
ls -la wow-detector screen-capture 2>/dev/null || echo "No binaries found"

echo ""
echo "Testing binaries..."

# Test WoW detector
echo "Testing wow-detector:"
if ./wow-detector --help >/dev/null 2>&1; then
    echo "  ✅ wow-detector is working"
else
    echo "  ❌ wow-detector failed to run"
fi

# Test screen capture utility
echo "Testing screen-capture:"
if ./screen-capture --help >/dev/null 2>&1; then
    echo "  ✅ screen-capture is working"
else
    echo "  ❌ screen-capture failed to run"
fi

echo ""
echo "Build script completed!"
echo ""
echo "You can now use:"
echo "  ./wow-detector --find-wow"
echo "  ./screen-capture --find-wow"