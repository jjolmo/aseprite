#!/bin/bash
#
# apply-xwayland-fixes.sh
#
# Actualiza Aseprite a último main oficial y aplica los fixes de XWayland.
#
# Uso:
#   curl -sL https://raw.githubusercontent.com/jjolmo/aseprite/jjolmo/crash-selecting-color-xwayland/apply-xwayland-fixes.sh | bash
#

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[SKIP]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

ASEPRITE_DIR="$HOME/aseprite"
cd "$ASEPRITE_DIR" || error "No se encontró $ASEPRITE_DIR"

# --- Update main ---
info "Actualizando a último main..."
git fetch origin
git checkout main
git reset --hard origin/main
git submodule update --init --recursive

# --- Apply fixes ---
info "Aplicando parches XWayland..."

if ! git remote | grep -q '^jjolmo$'; then
    git remote add jjolmo https://github.com/jjolmo/aseprite.git
fi
git fetch jjolmo jjolmo/crash-selecting-color-xwayland

for commit in \
    "2a80e0121a6e1556559421f13cd0fcf076a67458" \
    "1c516a23994fbe1b7f9871e0f680a521b9bc0dae"; do
    if git log --oneline -20 | grep -q "${commit:0:10}"; then
        warn "$(git log -1 --format='%s' "$commit")"
    else
        git cherry-pick "$commit" --no-edit || error "Cherry-pick falló en $commit"
        info "$(git log -1 --format='%s' "$commit")"
    fi
done

# laf submodule
cd laf
if ! git remote | grep -q '^jjolmo$'; then
    git remote add jjolmo https://github.com/jjolmo/laf.git
fi
git fetch jjolmo xwayland-fixes

LAF_COMMIT="8f1575bedfb4564075ed5b19857e6a402f0b107e"
if git log --oneline -20 | grep -q "${LAF_COMMIT:0:10}"; then
    warn "Fix crash picking colors on XWayland"
else
    git cherry-pick "$LAF_COMMIT" --no-edit || error "Cherry-pick falló en laf"
    info "Fix crash picking colors on XWayland"
fi
cd ..

git add laf
git commit -m "Update laf submodule with XWayland fix" --no-edit 2>/dev/null || true

echo ""
info "Parches aplicados. Ahora recompila con: cd $ASEPRITE_DIR && bash build.sh --auto --norun"
