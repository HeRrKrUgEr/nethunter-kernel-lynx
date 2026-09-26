#!/usr/bin/env bash
# build-magisk.sh — assemble un module Magisk installable depuis les .ko
#                    produits par build.sh (modules in-tree + out-of-tree).
#
# Usage : ./build-magisk.sh [KERNEL_VER]
#   - KERNEL_VER : version du noyau ciblé (défaut 6.12.92), sert à nommer le zip.
#   - Produit : output/nethunter-lynx-magisk-<KERNEL_VER>.zip
#
# Prérequis : build.sh a déjà été exécuté (output/modules/*.ko présents) et
#             les pilotes out-of-tree compilés (drivers/rtl8812au/88XXau.ko,
#             drivers/rtl8188eu/8188eu.ko).
#
# Le zip suit la structure du template officiel Magisk :
#   module.prop
#   META-INF/com/google/android/update-binary   (installer Magisk standard)
#   META-INF/com/google/android/updater-script  (marqueur "#MAGISK")
#   post-fs-data.sh  (insmod dans l'ordre des dépendances)
#   uninstall.sh     (rmmod best-effort)
#   system/lib/modules/*.ko
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAGISK_DIR="$ROOT_DIR/magisk"
OUTPUT_DIR="$ROOT_DIR/output"
DRIVERS_DIR="$ROOT_DIR/drivers"

KERNEL_VER="${1:-6.12.92}"
ZIP_NAME="nethunter-lynx-magisk-${KERNEL_VER}.zip"
ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"

log() { printf '\033[1;35m[magisk]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[magisk]\033[0m %s\n' "$*"; }

STAGE="$(mktemp -d "$ROOT_DIR/.magisk-stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

log "assemblage du module Magisk (noyau ${KERNEL_VER})"

# 1. Copie de la structure du module (module.prop, scripts, META-INF)
cp -a "$MAGISK_DIR"/. "$STAGE/"
# Les scripts doivent être exécutables (update-binary est exécuté directement
# par le recovery ; post-fs-data.sh/uninstall.sh par "sh" mais on garde +x).
chmod 755 "$STAGE/post-fs-data.sh" "$STAGE/uninstall.sh" \
          "$STAGE/META-INF/com/google/android/update-binary" 2>/dev/null || true

# 2. Modules in-tree (output/modules/*.ko)
mkdir -p "$STAGE/system/lib/modules"
count_in=0
for ko in "$OUTPUT_DIR"/modules/*.ko; do
  [ -f "$ko" ] || continue
  cp -f "$ko" "$STAGE/system/lib/modules/"
  count_in=$((count_in + 1))
done
log "modules in-tree copiés : ${count_in}"

# 3. Modules out-of-tree (88XXau.ko pour rtl8812au, 8188eu.ko pour rtl8188eu)
count_oot=0
for d in rtl8812au rtl8188eu; do
  ko="$(find "$DRIVERS_DIR/$d" -maxdepth 3 -name '*.ko' -print -quit 2>/dev/null || true)"
  if [ -n "$ko" ] && [ -f "$ko" ]; then
    cp -f "$ko" "$STAGE/system/lib/modules/"
    log "out-of-tree copié : $(basename "$ko") (depuis $d)"
    count_oot=$((count_oot + 1))
  else
    warn "ATTENTION : aucun .ko trouvé pour $d (driver non compilé)"
  fi
done

total=$((count_in + count_oot))
log "total modules inclus : ${total} (${count_in} in-tree + ${count_oot} out-of-tree)"

# 3bis. Strip des .ko (les modules sont buildés avec -g -gdwarf-5 : le debug
#       info multiplie la taille par ~8 ; on le retire avec llvm-strip).
if command -v llvm-strip >/dev/null 2>&1; then
  log "strip des .ko (llvm-strip --strip-debug)"
  before=$(du -sk "$STAGE/system/lib/modules" | cut -f1)
  find "$STAGE/system/lib/modules" -name '*.ko' -exec llvm-strip --strip-debug {} \;
  after=$(du -sk "$STAGE/system/lib/modules" | cut -f1)
  log "taille modules : ${before} KiB -> ${after} KiB"
else
  warn "llvm-strip absent : les .ko conservent leur debug info (zip volumineux)"
fi

# 4. Zip
mkdir -p "$OUTPUT_DIR"
rm -f "$ZIP_PATH"
( cd "$STAGE" && zip -qr -X "$ZIP_PATH" . )

log "zip produit : $ZIP_PATH"
ls -la "$ZIP_PATH"
echo
echo "Contenu du zip :"
unzip -l "$ZIP_PATH" | tail -5
