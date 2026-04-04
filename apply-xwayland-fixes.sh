#!/bin/bash
#
# Actualiza Aseprite a último main oficial y aplica los fixes de XWayland.
#
# Uso desde la carpeta de aseprite:
#   curl -sL https://raw.githubusercontent.com/jjolmo/aseprite/jjolmo/crash-selecting-color-xwayland/apply-xwayland-fixes.sh | bash
#

set -euo pipefail

info()  { echo -e "\033[0;32m[OK]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[SKIP]\033[0m $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

[[ -f "src/app/app.h" ]] || error "Ejecuta este script desde la carpeta de aseprite"

# Actualizar a último main
info "Actualizando a último main..."
git fetch origin
git checkout main
git reset --hard origin/main
git submodule update --init --recursive

# Añadir remote de jjolmo si no existe
for repo in . laf; do
    if ! git -C "$repo" remote | grep -q '^jjolmo$'; then
        git -C "$repo" remote add jjolmo "https://github.com/jjolmo/${repo##*/}.git"
    fi
done
git -C . remote set-url jjolmo https://github.com/jjolmo/aseprite.git

# Fetch fixes
git fetch jjolmo jjolmo/crash-selecting-color-xwayland
git -C laf fetch jjolmo xwayland-fixes

# Cherry-pick aseprite fixes
for commit in \
    2a80e0121a6e1556559421f13cd0fcf076a67458 \
    1c516a23994fbe1b7f9871e0f680a521b9bc0dae; do
    git cherry-pick "$commit" --no-edit 2>/dev/null && info "$(git log -1 --format='%s')" || warn "$(git log -1 --format='%s' "$commit")"
done

# Cherry-pick laf fix
cd laf
git cherry-pick 8f1575bedfb4564075ed5b19857e6a402f0b107e --no-edit 2>/dev/null && info "Fix crash picking colors on XWayland" || warn "Fix crash picking colors on XWayland"
cd ..

echo ""
info "Parches aplicados. Ahora recompila con: bash build.sh --auto --norun"
