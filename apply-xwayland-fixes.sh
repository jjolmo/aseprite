#!/bin/bash
#
# apply-xwayland-fixes.sh
#
# Applies XWayland crash/popup fixes on top of official Aseprite master.
# Run this from the root of a clean aseprite clone (with submodules initialized).
#
# Usage:
#   git clone --recursive https://github.com/aseprite/aseprite.git
#   cd aseprite
#   ./apply-xwayland-fixes.sh
#
# What it does:
#   1. Fetches the fix branches from jjolmo's forks
#   2. Cherry-picks the fix commits onto current HEAD
#   3. Updates the laf submodule to include the XWayland fix
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- Validate we're in an aseprite repo ---
if [[ ! -f "src/app/app.h" ]]; then
    error "This doesn't look like the aseprite repo root. Run this script from the aseprite directory."
fi

# --- Step 1: Apply laf submodule fix ---
info "Applying XWayland fix to laf submodule..."

cd laf

# Add jjolmo's fork as a temporary remote
if ! git remote | grep -q '^jjolmo$'; then
    git remote add jjolmo https://github.com/jjolmo/laf.git
fi
git fetch jjolmo xwayland-fixes

# Cherry-pick the laf fix
LAF_COMMIT="8f1575bedfb4564075ed5b19857e6a402f0b107e"
if git log --oneline | head -20 | grep -q "${LAF_COMMIT:0:10}"; then
    warn "laf fix already applied, skipping."
else
    git cherry-pick "$LAF_COMMIT" --no-edit || {
        error "Cherry-pick failed in laf. Resolve conflicts manually, then run: git cherry-pick --continue"
    }
    info "laf fix applied successfully."
fi

cd ..

# --- Step 2: Apply aseprite fixes ---
info "Applying aseprite fixes..."

# Add jjolmo's fork as a temporary remote
if ! git remote | grep -q '^jjolmo$'; then
    git remote add jjolmo https://github.com/jjolmo/aseprite.git
fi
git fetch jjolmo jjolmo/crash-selecting-color-xwayland

# Cherry-pick the aseprite commits (in order: oldest first)
ASEPRITE_COMMITS=(
    "2a80e0121a6e1556559421f13cd0fcf076a67458"  # Release mouse capture only on AppLeave, not WindowLeave
    "1c516a23994fbe1b7f9871e0f680a521b9bc0dae"  # Don't close pinnable popups on mouse move outside hot region
)

for commit in "${ASEPRITE_COMMITS[@]}"; do
    short="${commit:0:10}"
    if git log --oneline | head -20 | grep -q "$short"; then
        warn "Commit $short already applied, skipping."
    else
        git cherry-pick "$commit" --no-edit || {
            error "Cherry-pick failed for $commit. Resolve conflicts manually, then run: git cherry-pick --continue"
        }
        msg=$(git log -1 --format="%s" "$commit")
        info "Applied: $msg"
    fi
done

# --- Step 3: Stage the laf submodule update ---
info "Staging laf submodule pointer update..."
git add laf
git commit -m "Update laf submodule with XWayland fix" --no-edit 2>/dev/null || {
    warn "No submodule change to commit (may already be up to date)."
}

# --- Done ---
echo ""
info "All XWayland fixes applied successfully!"
info "Commits applied:"
info "  - [laf] Fix crash when picking colors outside screen bounds on XWayland"
info "  - Release mouse capture only on AppLeave, not WindowLeave"
info "  - Don't close pinnable popups on mouse move outside hot region"
echo ""
info "You can now build aseprite normally."
