#!/bin/bash
#
# apply-xwayland-fixes.sh
#
# Clona, parchea y compila Aseprite con los fixes de XWayland.
# Pensado para ejecutarse en un Ubuntu/Debian limpio.
#
# Uso:
#   curl -sL https://raw.githubusercontent.com/jjolmo/aseprite/jjolmo/crash-selecting-color-xwayland/apply-xwayland-fixes.sh | bash
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

INSTALL_DIR="$HOME/aseprite"

# --- Step 1: Install dependencies ---
info "Installing build dependencies..."
sudo apt-get update -qq
sudo apt-get install -y g++ clang cmake ninja-build libx11-dev libxcursor-dev libxi-dev libxrandr-dev libgl1-mesa-dev libfontconfig1-dev git curl unzip

# --- Step 2: Clone aseprite ---
if [[ -d "$INSTALL_DIR/.git" ]]; then
    info "Aseprite already cloned in $INSTALL_DIR, updating..."
    cd "$INSTALL_DIR"
    git fetch origin
    git checkout main
    git pull origin main
    git submodule update --init --recursive
else
    info "Cloning Aseprite..."
    git clone --recursive https://github.com/aseprite/aseprite.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# --- Step 3: Apply XWayland fixes ---
info "Applying XWayland fixes..."

# Add jjolmo fork remotes
if ! git remote | grep -q '^jjolmo$'; then
    git remote add jjolmo https://github.com/jjolmo/aseprite.git
fi
git fetch jjolmo jjolmo/crash-selecting-color-xwayland

# Cherry-pick aseprite commits (oldest first)
ASEPRITE_COMMITS=(
    "2a80e0121a6e1556559421f13cd0fcf076a67458"  # Release mouse capture only on AppLeave, not WindowLeave
    "1c516a23994fbe1b7f9871e0f680a521b9bc0dae"  # Don't close pinnable popups on mouse move outside hot region
)

for commit in "${ASEPRITE_COMMITS[@]}"; do
    short="${commit:0:10}"
    if git log --oneline -20 | grep -q "$short"; then
        warn "Commit $short already applied, skipping."
    else
        git cherry-pick "$commit" --no-edit || {
            error "Cherry-pick failed for $commit. Resolve conflicts manually."
        }
        msg=$(git log -1 --format="%s" "$commit")
        info "Applied: $msg"
    fi
done

# Apply laf submodule fix
info "Applying laf submodule fix..."
cd laf
if ! git remote | grep -q '^jjolmo$'; then
    git remote add jjolmo https://github.com/jjolmo/laf.git
fi
git fetch jjolmo xwayland-fixes

LAF_COMMIT="8f1575bedfb4564075ed5b19857e6a402f0b107e"
if git log --oneline -20 | grep -q "${LAF_COMMIT:0:10}"; then
    warn "laf fix already applied, skipping."
else
    git cherry-pick "$LAF_COMMIT" --no-edit || {
        error "Cherry-pick failed in laf."
    }
    info "Applied: Fix crash when picking colors outside screen bounds on XWayland"
fi
cd ..

git add laf
git commit -m "Update laf submodule with XWayland fix" --no-edit 2>/dev/null || true

# --- Step 4: Build with the official build.sh ---
info "Building Aseprite (this will download Skia and compile)..."
bash build.sh --auto --norun

# --- Done ---
echo ""
info "============================================"
info "  Aseprite compiled successfully!"
info "============================================"
info ""
info "  Binary: $INSTALL_DIR/build/release/bin/aseprite"
info ""
info "  To run:  $INSTALL_DIR/build/release/bin/aseprite"
info ""
info "  To update later, just run this script again."
info "============================================"
