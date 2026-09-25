#!/usr/bin/env bash
#
# build.sh — Kernel NetHunter pour Google Pixel 7a (lynx)
#            GKI android16-6.12 — methode LKM (modules chargeables)
#
# Usage :
#   ./build.sh           # build complet : noyau + modules in-tree + pilotes out-of-tree
#   JOBS=4 ./build.sh    # limiter le parallelisme (si RAM insuffisante)
#   BRANCH=... ./build.sh
#
# Prerequis (Arch Linux) :
#   sudo pacman -S --needed base-devel git python clang llvm lld bc cpio \
#     libelf pahole dtc zip unzip
#
# Le resultat est depose dans ./output/ :
#   modules/  -> fichiers .ko (a charger sur le device via insmod/modprobe)
#   Image     -> image noyau GKI (reference)
#   Module.symvers, System.map, .config
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="${ROOT_DIR}/kernel/common"
OUT_DIR="${ROOT_DIR}/out"
DRIVERS_DIR="${ROOT_DIR}/drivers"
OUTPUT_DIR="${ROOT_DIR}/output"
CONFIGS_DIR="${ROOT_DIR}/configs"

BRANCH="${BRANCH:-android16-6.12}"
KERNEL_URL="https://android.googlesource.com/kernel/common"
JOBS="${JOBS:-$(nproc)}"
ARCH="arm64"

export ARCH

log() { printf '\033[1;36m[build]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[build]\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. Sources GKI
# ---------------------------------------------------------------------------
log "1/7 : sources GKI (${BRANCH})"
mkdir -p "${ROOT_DIR}/kernel"
if [ ! -d "${KERNEL_DIR}/.git" ]; then
  git clone --depth 1 -b "${BRANCH}" "${KERNEL_URL}" "${KERNEL_DIR}"
else
  log "  deja clone : ${KERNEL_DIR}"
fi

# ---------------------------------------------------------------------------
# 2. Fragment de config
# ---------------------------------------------------------------------------
log "2/7 : installation du fragment nethunter.fragment"
mkdir -p "${KERNEL_DIR}/arch/${ARCH}/configs"
cp -f "${CONFIGS_DIR}/nethunter.fragment" "${KERNEL_DIR}/arch/${ARCH}/configs/"

# ---------------------------------------------------------------------------
# 3. Generation .config (gki_defconfig + fragment, dependances resolues)
# ---------------------------------------------------------------------------
log "3/7 : generation .config (gki_defconfig + nethunter.fragment)"
make -C "${KERNEL_DIR}" O="${OUT_DIR}" ARCH="${ARCH}" LLVM=1 \
  gki_defconfig nethunter.fragment
make -C "${KERNEL_DIR}" O="${OUT_DIR}" ARCH="${ARCH}" LLVM=1 olddefconfig

# ---------------------------------------------------------------------------
# 4. Compilation noyau + modules in-tree
# ---------------------------------------------------------------------------
log "4/7 : compilation (jobs=${JOBS})"
make -C "${KERNEL_DIR}" O="${OUT_DIR}" ARCH="${ARCH}" LLVM=1 \
  -j"${JOBS}" KCFLAGS="-D__ANDROID_COMMON_KERNEL__"

# ---------------------------------------------------------------------------
# 5. Pilotes out-of-tree (RTL8812AU / RTL8188EU)
# ---------------------------------------------------------------------------
log "5/7 : pilotes out-of-tree"
mkdir -p "${DRIVERS_DIR}"
OOT_DRIVERS=(
  "rtl8812au|https://github.com/aircrack-ng/rtl8812au.git"
  "rtl8188eu|https://github.com/aircrack-ng/rtl8188eus.git"
)
for entry in "${OOT_DRIVERS[@]}"; do
  name="${entry%%|*}"
  url="${entry##*|}"
  d="${DRIVERS_DIR}/${name}"
  if [ ! -d "${d}/.git" ]; then
    log "  clonage ${name}"
    git clone --depth 1 "${url}" "${d}"
  fi
  log "  build ${name} (.ko)"
  # non bloquant : un echec sur un pilote out-of-tree ne casse pas le build global
  make -C "${KERNEL_DIR}" O="${OUT_DIR}" ARCH="${ARCH}" LLVM=1 \
    M="${d}" modules || err "  echec ${name} (non bloquant)"
done

# ---------------------------------------------------------------------------
# 6. Collecte des artefacts
# ---------------------------------------------------------------------------
log "6/7 : collecte des artefacts dans ${OUTPUT_DIR}"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}/modules"

# modules in-tree
find "${OUT_DIR}" -name '*.ko' -exec cp -f {} "${OUTPUT_DIR}/modules/" \;
# modules out-of-tree
for name in rtl8812au rtl8188eu; do
  find "${DRIVERS_DIR}/${name}" -name '*.ko' \
    -exec cp -f {} "${OUTPUT_DIR}/modules/" \; 2>/dev/null || true
done

# artefacts noyau de reference
cp -f "${OUT_DIR}/arch/${ARCH}/boot/Image"    "${OUTPUT_DIR}/" 2>/dev/null || true
cp -f "${OUT_DIR}/arch/${ARCH}/boot/Image.gz" "${OUTPUT_DIR}/" 2>/dev/null || true
cp -f "${OUT_DIR}/Module.symvers"             "${OUTPUT_DIR}/" 2>/dev/null || true
cp -f "${OUT_DIR}/System.map"                 "${OUTPUT_DIR}/" 2>/dev/null || true
cp -f "${OUT_DIR}/.config"                    "${OUTPUT_DIR}/" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 7. Resume
# ---------------------------------------------------------------------------
log "7/7 : termine"
echo ""
echo "Modules produits :"
find "${OUTPUT_DIR}/modules" -name '*.ko' -printf '  %f\n' | sort
echo ""
echo "Artefacts dans : ${OUTPUT_DIR}"
