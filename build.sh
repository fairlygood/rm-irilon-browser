#!/bin/bash

echo "============================="
echo "Building Irilon Browser..."
echo "============================="

echo "Choose build type:"
echo "1) Local build (for testing on this machine)"
echo "2) Device build (for RMPP / RMPM / aarch64)"
echo "3) Device build (for reMarkable 2 / ARMv7)"
echo "4) GitHub release build (both ARM64 and ARMv7)"
read -p "Enter choice (1, 2, 3, or 4): " choice

echo "Cleaning up previous builds..."
rm -rf dist-local dist-rm qml_output

echo "Building frontend..."
mkdir qml_output
(
    cd qml-src
    cp manifest.json ../qml_output/
    /usr/lib/qt6/libexec/rcc --binary -o ../qml_output/resources.rcc application.qrc 2>/dev/null || echo "Warning: Could not build resources.rcc"
)

echo "==========================="
echo "Compiling backend Go code..."
echo "==========================="

if [ "$choice" = "1" ]; then
    echo "Building locally..."

    # Create dist-local structure
    mkdir -p dist-local/irilon/backend

    # Build backend locally
    cd go-src
    go build -o ../dist-local/irilon/backend/entry main.go
    cd ..

    # Copy frontend files to dist-local
    cp qml_output/manifest.json dist-local/irilon/ 2>/dev/null || true
    cp qml_output/resources.rcc dist-local/irilon/ 2>/dev/null || true
    cp qml-src/icon.png dist-local/irilon/ 2>/dev/null || true

    # Install to appload
    echo "Installing to appload..."
    rm -rf ./rm-appload/applications_root/irilon
    cp -r dist-local/irilon ./rm-appload/applications_root/irilon

    echo "Local build complete!"
    echo "Built files are in: dist-local/irilon/"
    echo "Installed to appload. Run appload to test."

elif [ "$choice" = "2" ]; then
    echo "Building release for reMarkable..."

    # Create dist-rm structure
    mkdir -p dist-rm/irilon/backend

    # Build for ARM64 (aarch64)
    cd go-src
    env GOOS=linux GOARCH=arm64 go build -o ../dist-rm/irilon/backend/entry main.go
    cd ..

    # Copy frontend files to dist-rm
    cp qml_output/manifest.json dist-rm/irilon/ 2>/dev/null || true
    cp qml_output/resources.rcc dist-rm/irilon/ 2>/dev/null || true
    cp qml-src/icon.png dist-rm/irilon/ 2>/dev/null || true

    echo "Device build complete!"
    echo "Built files are in: dist-rm/irilon/"
    echo "Ready to transfer to reMarkable device."

    # Send to device
    read -p "Do you want to transfer to device? (y/N): " transfer_choice
    if [[ "$transfer_choice" =~ ^[Yy]$ ]]; then
        read -p "Enter device IP address: " device_ip
        echo "Transferring files to $device_ip:~/xovi/exthome/appload/irilon..."

        # Remove existing app folder on device to ensure clean installation - seems to work better?
        ssh root@$device_ip "rm -rf ~/xovi/exthome/appload/irilon"

        # Create the remote directory
        ssh root@$device_ip "mkdir -p ~/xovi/exthome/appload/irilon"

        scp -r dist-rm/irilon/* root@$device_ip:~/xovi/exthome/appload/irilon/

        if [ $? -eq 0 ]; then
            echo "Transfer successful!"
            echo "Application installed to device."
        else
            echo "Transfer failed!"
        fi
    else
        echo "Skipping transfer."
    fi

elif [ "$choice" = "3" ]; then
    echo "Building for reMarkable 2 (ARMv7)..."

    # Create dist-rm structure
    mkdir -p dist-rm/irilon/backend

    # Build for ARMv7 (arm)
    cd go-src
    env GOOS=linux GOARCH=arm GOARM=7 go build -o ../dist-rm/irilon/backend/entry main.go
    cd ..

    # Copy frontend files to dist-rm
    cp qml_output/manifest.json dist-rm/irilon/ 2>/dev/null || true
    cp qml_output/resources.rcc dist-rm/irilon/ 2>/dev/null || true
    cp qml-src/icon.png dist-rm/irilon/ 2>/dev/null || true

    echo "Device build complete!"
    echo "Built files are in: dist-rm/irilon/"
    echo "Ready to transfer to reMarkable device."

    # Send to device
    read -p "Do you want to transfer to device? (y/N): " transfer_choice
    if [[ "$transfer_choice" =~ ^[Yy]$ ]]; then
        read -p "Enter device IP address: " device_ip
        echo "Transferring files to $device_ip:~/xovi/exthome/appload/irilon..."

        # Remove existing app folder on device to ensure clean installation - seems to work better?
        ssh root@$device_ip "rm -rf ~/xovi/exthome/appload/irilon"

        # Create the remote directory
        ssh root@$device_ip "mkdir -p ~/xovi/exthome/appload/irilon"

        scp -r dist-rm/irilon/* root@$device_ip:~/xovi/exthome/appload/irilon/

        if [ $? -eq 0 ]; then
            echo "Transfer successful!"
            echo "Application installed to device."
        else
            echo "Transfer failed!"
        fi
    else
        echo "Skipping transfer."
    fi

elif [ "$choice" = "4" ]; then
    echo "Building GitHub release (ARM64 + ARMv7)..."

    # Get date for versioning
    VERSION=$(date +%Y-%m-%d)

    # Create release directories
    mkdir -p dist-release/irilon-arm64/backend
    mkdir -p dist-release/irilon-armv7/backend

    # Build frontend (shared by both)
    echo "Building frontend..."
    cp qml_output/manifest.json dist-release/irilon-arm64/ 2>/dev/null || true
    cp qml_output/resources.rcc dist-release/irilon-arm64/ 2>/dev/null || true
    cp qml-src/icon.png dist-release/irilon-arm64/ 2>/dev/null || true
    cp qml_output/manifest.json dist-release/irilon-armv7/ 2>/dev/null || true
    cp qml_output/resources.rcc dist-release/irilon-armv7/ 2>/dev/null || true
    cp qml-src/icon.png dist-release/irilon-armv7/ 2>/dev/null || true

    # Build ARM64 (for RMPP/RMPM)
    echo "Building ARM64 version..."
    cd go-src
    env GOOS=linux GOARCH=arm64 go build -o ../dist-release/irilon-arm64/backend/entry main.go
    cd ..

    # Build ARMv7 (for reMarkable 2)
    echo "Building ARMv7 version..."
    cd go-src
    env GOOS=linux GOARCH=arm GOARM=7 go build -o ../dist-release/irilon-armv7/backend/entry main.go
    cd ..

    # Create zip files
    echo "Creating zip archives..."
    cd dist-release
    zip -r "irilon-${VERSION}-arm64.zip" irilon-arm64
    zip -r "irilon-${VERSION}-armv7.zip" irilon-armv7
    cd ..

    echo "Release build complete!"
    echo "Zip files created in dist-release/:"
    echo "  - irilon-${VERSION}-arm64.zip (for RMPP/RMPM)"
    echo "  - irilon-${VERSION}-armv7.zip (for reMarkable 2)"

else
    echo "Invalid choice. Exiting."
    exit 1
fi

# Clean up temp files
rm -rf qml_output

echo "=========================================="
echo "Build process complete."
echo "=========================================="