# Procédure de build détaillée

## Contexte technique

Le Pixel 7a (`lynx`, SoC Tensor G2 `gs201`) sous Android 14 utilise le noyau
GKI Google `kernel/common`, branche `android14-6.1` (version 6.1.145). Le fork
historique `android_kernel_google_gs201` est arrêté à Android 14.

Contrainte GKI : le noyau est « gelé » (ABI stable). Toute modification
vendor/OEM est un **module chargeable** (`.ko`), pas une modification du
`boot.img`. On ne patche pas le noyau, on construit des modules.

## Cible exacte

- Branche : `android14-6.1` de `https://android.googlesource.com/kernel/common`
- Commit : `edaaac4d5c85cb9fb220767a9e5f859cb730fb27` (= build GKI `ab16017558`)
- Noyau : `6.1.145-android14-11-gedaaac4d5c85` (KMI generation 11)
- Vermagic produit :
  `6.1.145-android14-11-gedaaac4d5c85 SMP preempt mod_unload modversions aarch64`

Le vermagic est déterministe : `scripts/setlocalversion` reçoit `BRANCH` +
`KMI_GENERATION` (définis dans `build.config.constants`/`build.config.common`)
et calcule `-android14-11-gedaaac4d5c85`. Ces deux variables **doivent** être
exportées pendant le `make` (le script `build.sh` le fait).

## Prérequis hôte (Arch Linux)

```bash
sudo pacman -S --needed base-devel git python clang llvm lld bc cpio \
  libelf pahole dtc zip unzip libxml2
```

### Toolchain clang 17 (obligatoire)

Le clang 22 livré par Arch est **trop récent** pour ce noyau 6.1 : il durcit
`-Wincompatible-pointer-types-discards-qualifiers` et casse
`tools/bpf/resolve_btfids` (libbpf embarquée). Google a buildé ce noyau avec
clang 17 (`r487747c`, clang 17.0.2).

Télécharger le tarball LLVM 17.0.6 officiel :

```bash
mkdir -p ~/toolchain && cd ~/toolchain
curl -L -o clang-17.0.6.tar.xz \
  https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.6/clang+llvm-17.0.6-x86_64-linux-gnu-ubuntu-22.04.tar.xz
tar -xf clang-17.0.6.tar.xz
```

Le `ld.lld` du tarball (build Ubuntu) dépend de `libxml2.so.2`. Arch fournit
`libxml2.so.16` : créer un symlink local et l'exposer via `LD_LIBRARY_PATH`
(le warning « no version information available » est inoffensif) :

```bash
mkdir -p ~/toolchain/libs
ln -sf /usr/lib/libxml2.so.16 ~/toolchain/libs/libxml2.so.2
export LD_LIBRARY_PATH=~/toolchain/libs
```

`build.sh` fait ce symlink automatiquement dans `.toolchain-libs/`.

## BTF désactivé (fragment)

`CONFIG_DEBUG_INFO_BTF` est désactivé par le fragment (`configs/nethunter.config`).
C'est nécessaire car `tools/bpf/resolve_btfids` (libbpf embarquée du 6.1) ne
compile pas avec clang 16+ sous `-Werror`. BTF n'est requis ni pour le vermagic
ni pour les CRC modversions des modules WiFi/BT : le désactiver ne change rien
au chargement des modules.

## Build

```bash
CLANG_DIR=$HOME/toolchain/clang+llvm-17.0.6-x86_64-linux-gnu-ubuntu-22.04 \
  ./build.sh
```

Déroulé :

1. Clone `kernel/common` (`android14-6.1`) dans `kernel/common`, puis
   `git fetch --depth 1 origin <commit>` + `git checkout <commit>`
   (commit précis `edaaac4d5c85`, PAS le HEAD de la branche qui a avancé
   jusqu'à 6.1.177).
2. Copie `configs/nethunter.config` dans `arch/arm64/configs/`.
3. `make gki_defconfig nethunter.config` (fragment merge via merge_config.sh).
4. `make -j$(nproc) KCFLAGS=-D__ANDROID_COMMON_KERNEL__` : noyau + modules
   in-tree.
5. Build des pilotes out-of-tree (recette FORTIFY, voir `drivers/README.md`).
6. Collecte des `.ko` + artefacts dans `output/`.

### Module Magisk

```bash
./build-magisk.sh 6.1.145    # output/nethunter-lynx-magisk-6.1.145.zip
```

## Vérification du vermagic

```bash
modinfo output/modules/cfg80211.ko | grep vermagic
# => 6.1.145-android14-11-gedaaac4d5c85 SMP preempt mod_unload modversions aarch64
```

## Contenu de `output/`

```
output/
├── modules/
│   ├── cfg80211.ko, mac80211.ko
│   ├── rt2x00lib.ko, rt2x00usb.ko, rt2800lib.ko, rt2800usb.ko
│   ├── ath.ko, ath9k_hw.ko, ath9k_common.ko, ath9k_htc.ko
│   ├── rtl8xxxu.ko, btusb.ko, hci_uart.ko
│   ├── 88XXau.ko  (rtl8812au out-of-tree)
│   └── 8188eu.ko  (rtl8188eu out-of-tree)
├── Module.symvers, .config, System.map, Image
```

## Déploiement (contraintes)

`CONFIG_MODVERSIONS=y` + `CONFIG_MODULE_SIG=y` : un `.ko` ne se charge que sur
un noyau de version exactement identique (vermagic + CRC + signature). Voir
`docs/VERMAGIC.md`. Magisk/KernelSU avec `insmod` au boot est la voie la plus
pratique.

## Étapes restantes (hors scope de ce dépôt)

- Fourniture du rootfs NetHunter (séparé, côté Kali).
- Validation matérielle (monitor mode, injection, HID) sur un lynx déverrouillé.
