#!/usr/bin/env bash
set -e

# Versions & Hashes (Pinned for reproducibility and trust)
AUTOIT_VER="3.3.18.0"
AUTOIT_SHA256="ceb666a993a9f62621c3a0d4ee602774b2e7f543de1f08ec0380632ee3f89beb"
AUTOIT_URL="https://www.autoitscript.com/autoit3/files/archive/autoit/autoit-v${AUTOIT_VER}.zip"

AHK_VER="1.1.37.02"
AHK_SHA256="6f3663f7cdd25063c8c8728f5d9b07813ced8780522fd1f124ba539e2854215f"
AHK_URL="https://github.com/AutoHotkey/AutoHotkey/releases/download/v${AHK_VER}/AutoHotkey_${AHK_VER}.zip"

PYTHON_VER="3.13.12"
PYTHON_SHA256="76f238f606250c87c6beac75dccd35ee99070a13490555936abb6cb64ecce3d0"
PYTHON_URL="https://www.python.org/ftp/python/${PYTHON_VER}/python-${PYTHON_VER}-embed-amd64.zip"

WINSPY_VER="1.8.4"
WINSPY_SHA256="f3ec87e83d038c812dc7a0628a7d0890aec88dff7a262c2ddfe2b52559e1b069"
WINSPY_URL="https://github.com/strobejb/winspy/releases/download/v${WINSPY_VER}/WinSpy_Release_x86.zip"

TOOLS_DIR="/opt/winebot/windows-tools"
mkdir -p "$TOOLS_DIR"

verify_hash() {
    local file="$1"
    local expected="$2"
    echo "Verifying integrity of $(basename "$file")..."
    echo "$expected  $file" | sha256sum -c - || {
        echo "ERROR: Checksum mismatch for $file" >&2
        echo "Expected: $expected" >&2
        echo "Computed: $(sha256sum "$file" | awk '{print $1}')" >&2
        exit 1
    }
}

# --- 1. AutoIt v3 ---
echo "Downloading AutoIt..."
mkdir -p "$TOOLS_DIR/AutoIt"
curl -sL -o /tmp/autoit.zip "$AUTOIT_URL"
verify_hash /tmp/autoit.zip "$AUTOIT_SHA256"
unzip -q -o /tmp/autoit.zip -d "$TOOLS_DIR/AutoIt"
rm /tmp/autoit.zip
# AutoIt zip often has a nested "install" folder structure, let's flatten if needed or just use as is.
# Usually it extracts to "install/". Let's check if we need to move files.
if [ -d "$TOOLS_DIR/AutoIt/install" ]; then
    mv "$TOOLS_DIR/AutoIt/install"/* "$TOOLS_DIR/AutoIt/"
    rmdir "$TOOLS_DIR/AutoIt/install"
fi
echo "AutoIt installed."

# --- 2. AutoHotkey v1.1 ---
echo "Downloading AutoHotkey..."
mkdir -p "$TOOLS_DIR/AutoHotkey"
curl -sL -o /tmp/ahk.zip "$AHK_URL"
verify_hash /tmp/ahk.zip "$AHK_SHA256"
unzip -q -o /tmp/ahk.zip -d "$TOOLS_DIR/AutoHotkey"
rm /tmp/ahk.zip
echo "AutoHotkey installed."

# --- 3. Python Embedded ---
echo "Downloading Python ${PYTHON_VER}..."
mkdir -p "$TOOLS_DIR/Python"
curl -sL -o /tmp/python.zip "$PYTHON_URL"
verify_hash /tmp/python.zip "$PYTHON_SHA256"
unzip -q -o /tmp/python.zip -d "$TOOLS_DIR/Python"
rm /tmp/python.zip

# Enable 'site' package for pip to work.
# Embedded Python ships a pythonXY._pth file; detect it dynamically.
PTH_FILE="$(find "$TOOLS_DIR/Python" -maxdepth 1 -name 'python*._pth' | head -n 1)"
if [ -n "$PTH_FILE" ] && [ -f "$PTH_FILE" ]; then
    sed -i 's/^#import site/import site/' "$PTH_FILE"
fi

echo "Python installed."

# --- 4. WinSpy++ ---
echo "Downloading WinSpy++..."
mkdir -p "$TOOLS_DIR/WinSpy"
curl -sL -o /tmp/winspy.zip "$WINSPY_URL"
verify_hash /tmp/winspy.zip "$WINSPY_SHA256"
unzip -q -o /tmp/winspy.zip -d "$TOOLS_DIR/WinSpy"
rm /tmp/winspy.zip
echo "WinSpy++ installed."

# Cleanup
rm -rf /tmp/*.zip
