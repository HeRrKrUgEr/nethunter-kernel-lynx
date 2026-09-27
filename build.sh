#!/usr/bin/env bash
# ============================================================================
# build.sh — Kernel Kali NetHunter pour Google Pixel 7a (lynx)
#            GKI android14-6.1 — methode LKM (modules chargeables .ko)
#
# Cible EXACTE :
#   kernel/common  branche android14-6.1, commit edaaac4d5c85
#   noyau 6.1.145-android14 (KMI generation 11)
#   vermagic : 6.1.145-android14-11-gedaaac4d5c85 SMP preempt mod_unload
#              modversions aarch64
#
# Usage :
#   ./build.sh                  # build complet (noyau + modules + pilotes)
#   JOBS=4 ./build.sh           # limiter le parallelisme (RAM insuffisante)
#   CLANG_DIR=/chemin/clang17 ./build.sh
#
# Prerequis (cf. docs/BUILD.md) :
#   clang 17 (LLVM 17.x) + lld + llvm-ar/nm/objcopy/strip. Le clang 22 d'Arch
#   est TROP recent pour ce noyau 6.1 (-Werror casse libbpf/resolve_btfids).
#   Ce script attend CLANG_DIR pointant sur un clang 17 (tarball LLVM 17.x ou
#   prebuilt AOSP r487747c).
#
# Resultat dans ./output/ :
#   modules/*.ko  (in-tree + out-of-tree)
#   Module.symvers, .config, System.map, Image
# ============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="${ROOT_DIR}/kernel/common"
OUT_DIR="${ROOT_DIR}/out"
DRIVERS_DIR="${ROOT_DIR}/drivers"
OUTPUT_DIR="${ROOT_DIR}/output"
CONFIGS_DIR="${ROOT_DIR}/configs"

BRANCH="${BRANCH:-android14-6.1}"
COMMIT="${COMMIT:-edaaac4d5c85cb9fb220767a9e5f859cb730fb27}"
KMI_GENERATION="${KMI_GENERATION:-11}"
KERNEL_URL="https://android.googlesource.com/kernel/common"
JOBS="${JOBS:-$(nproc)}"
ARCH="arm64"

# La version du noyau (vermagic) est derivee de BRANCH + KMI_GENERATION + hash
# git (scripts/setlocalversion). Ces variables DOIVENT etre exportees.
export ARCH BRANCH KMI_GENERATION

log() { printf '\033[1;36m[build]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[build]\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------------------
# Toolchain clang 17
# ---------------------------------------------------------------------------
CLANG_DIR="${CLANG_DIR:-/home/judas/nethunter-lynx/toolchain/clang+llvm-17.0.6-x86_64-linux-gnu-ubuntu-22.04}"
if [ -d "${CLANG_DIR}/bin" ]; then
  LLVM="${CLANG_DIR}/bin/"
  # lld du tarball LLVM (build Ubuntu) est linke contre libxml2.so.2 (soname
  # Ubuntu). Arch fournit libxml2.so.16 : on cree un symlink local et on le
  # met dans LD_LIBRARY_PATH (le warning "no version information" est inoffensif).
  LIBS_DIR="${ROOT_DIR}/.toolchain-libs"
  mkdir -p "${LIBS_DIR}"
  if [ ! -e "${LIBS_DIR}/libxml2.so.2" ]; then
    for cand in /usr/lib/libxml2.so.16 /usr/lib64/libxml2.so.16; do
      if [ -e "$cand" ]; then ln -sf "$cand" "${LIBS_DIR}/libxml2.so.2"; break; fi
    done
  fi
  export LD_LIBRARY_PATH="${LIBS_DIR}:${LD_LIBRARY_PATH:-}"
else
  LLVM=1
  err "CLANG_DIR introuvable : ${CLANG_DIR}"
  err "clang 17 requis (voir docs/BUILD.md) — fallback clang systeme (risque d'echec)."
fi

# ---------------------------------------------------------------------------
# 1. Sources GKI
# ---------------------------------------------------------------------------
log "1/7 : sources GKI ${BRANCH} @ ${COMMIT}"
mkdir -p "${ROOT_DIR}/kernel"
if [ ! -d "${KERNEL_DIR}/.git" ]; then
  git clone --depth 1 -b "${BRANCH}" "${KERNEL_URL}" "${KERNEL_DIR}"
  ( cd "${KERNEL_DIR}" && git fetch --depth 1 origin "${COMMIT}" && git checkout "${COMMIT}" )
else
  log "  deja clone : ${KERNEL_DIR} (verifier commit = ${COMMIT})"
fi

# ---------------------------------------------------------------------------
# 2. Fragment de config
# ---------------------------------------------------------------------------
log "2/7 : installation du fragment nethunter.config"
mkdir -p "${KERNEL_DIR}/arch/${ARCH}/configs"
cp -f "${CONFIGS_DIR}/nethunter.config" "${KERNEL_DIR}/arch/${ARCH}/configs/"

# ---------------------------------------------------------------------------
# 3. Generation .config (gki_defconfig + fragment)
# ---------------------------------------------------------------------------
log "3/7 : generation .config (gki_defconfig + nethunter.config)"
make -C "${KERNEL_DIR}" O="${OUT_DIR}" ARCH="${ARCH}" LLVM="${LLVM}" \
  gki_defconfig nethunter.config

# ---------------------------------------------------------------------------
# 4. Compilation noyau + modules in-tree
# ---------------------------------------------------------------------------
log "4/7 : compilation (jobs=${JOBS})"
make -C "${KERNEL_DIR}" O="${OUT_DIR}" ARCH="${ARCH}" LLVM="${LLVM}" \
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
  # Workaround FORTIFY_SOURCE + clang : drivers legacy utilisant u8 data[0].
  # -D__NO_FORTIFY desactive fortify-string.h ; -Wno-error demote les warnings
  # generiques SANS toucher aux -Werror=implicit-function-declaration /
  # incompatible-pointer-types. CONFIG_PLATFORM_ARM64_RPI=y evite la glue
  # Android legacy (rtw_android.c -> linux/wlan_plat.h, absent du mainline).
  OOT_CFLAGS="-D__NO_FORTIFY -Wno-error -Wno-uninitialized -Wno-unknown-warning-option -Wno-array-bounds -Wno-address-of-packed-member"
  make -C "${d}" ARCH="${ARCH}" LLVM="${LLVM}" \
    CONFIG_PLATFORM_ARM64_RPI=y CONFIG_PLATFORM_I386_PC=n CONFIG_PLATFORM_ANDROID_ARM64=n \
    KSRC="${KERNEL_DIR}" O="${OUT_DIR}" \
    USER_EXTRA_CFLAGS="${OOT_CFLAGS}" \
    modules || err "  echec ${name}"
done

# ---------------------------------------------------------------------------
# 6. Collecte des artefacts
# ---------------------------------------------------------------------------
log "6/7 : collecte des artefacts dans ${OUTPUT_DIR}"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}/modules"

find "${OUT_DIR}" -name '*.ko' -exec cp -f {} "${OUTPUT_DIR}/modules/" \;
for name in rtl8812au rtl8188eu; do
  find "${DRIVERS_DIR}/${name}" -name '*.ko' \
    -exec cp -f {} "${OUTPUT_DIR}/modules/" \; 2>/dev/null || true
done

cp -f "${OUT_DIR}/arch/${ARCH}/boot/Image"    "${OUTPUT_DIR}/" 2>/dev/null || true
cp -f "${OUT_DIR}/arch/${ARCH}/boot/Image.gz" "${OUTPUT_DIR}/" 2>/dev/null || true
cp -f "${OUT_DIR}/Module.symvers"             "${OUTPUT_DIR}/" 2>/dev/null || true
cp -f "${OUT_DIR}/System.map"                 "${OUTPUT_DIR}/" 2>/dev/null || true
cp -f "${OUT_DIR}/.config"                    "${OUTPUT_DIR}/" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 7. Resume + verification vermagic
# ---------------------------------------------------------------------------
log "7/7 : termine"
echo ""
echo "Version noyau (vermagic attendu) :"
make -C "${KERNEL_DIR}" O="${OUT_DIR}" ARCH="${ARCH}" LLVM="${LLVM}" -s kernelrelease
echo ""
echo "Modules produits :"
find "${OUTPUT_DIR}/modules" -name '*.ko' -printf '  %f\n' | sort
echo ""
echo "Artefacts dans : ${OUTPUT_DIR}"
