# Procédure de build détaillée

## Contexte technique

Le Pixel 7a (`lynx`, SoC Tensor G2 `gs201`) sous LineageOS 23.2 (Android 16)
utilise le noyau GKI Google `kernel/common`, branche `android16-6.12`
(version exacte ici : 6.12.92). Le fork historique `android_kernel_google_gs201`
est arrêté à Android 14 (lineage-21) et ne couvre pas Android 16.

Contrainte GKI : le noyau est « gelé ». Google impose que toute modification
vendor/OEM soit un **module chargeable** (`vendor_boot` / `vendor_dlkm`), pas une
modification du `boot.img` GKI. C'est pourquoi on ne patche pas le noyau et on
construit des `.ko`.

### Pourquoi le builder Kali n'est pas utilisé

- `kali-nethunter-kernel` (build.sh interactif) ne fournit des patches que pour
  les noyaux 3.04 → 5.4. Rien pour 6.x.
- Son patch « mac80211 packet injection » cible les noyaux anciens ; la
  fonctionnalité est **déjà dans mainline** depuis 5.7 (monitor mode +
  injection + radiotap natifs).
- Ses `local.config` sont orientés GCC 4.9 / clang 10, inadaptés à un noyau 6.12
  qui exige clang/LLVM récent.

## Prérequis hôte (Arch Linux)

```bash
sudo pacman -S --needed base-devel git python clang llvm lld bc cpio \
  libelf pahole dtc zip unzip
```

Vérifier :

```bash
clang --version   # >= 18 recommandé (22 testé ici)
ld.lld --version  # lld doit être présent (LLVM=1)
```

Pas besoin de cross-compileur GCC : `LLVM=1` fait tout via clang/lld.

## Build

```bash
./build.sh
```

Déroulé :

1. Clone `kernel/common` (`android16-6.12`) dans `kernel/common` (shallow).
2. Copie `configs/nethunter.fragment` dans `arch/arm64/configs/`.
3. `make LLVM=1 O=out ARCH=arm64 gki_defconfig nethunter.fragment`
   puis `olddefconfig` pour résoudre les dépendances.
4. `make LLVM=1 O=out ARCH=arm64 -j$(nproc)` : noyau + modules in-tree.
5. Build des pilotes out-of-tree dans `drivers/` :
   - `rtl8812au` (aircrack-ng/rtl8812au)
   - `rtl8188eu` (aircrack-ng/rtl8188eus)
6. Collecte des `.ko` + artefacts dans `output/`.

### RAM / LTO

Le `gki_defconfig` n'active pas LTO (l'option LTO n'y figure pas). Le build
manuel est donc sans LTO, ce qui évite la saturation mémoire. Si OOM :
`JOBS=4 ./build.sh`.

La stack Rust du noyau est désactivée par le fragment (`CONFIG_RUST=n`) pour
éviter la dépendance `rustc`/`bindgen` ; elle n'est pas nécessaire aux modules
WiFi/BT/gadget produits ici.

## Contenu de `output/`

```
output/
├── modules/
│   ├── cfg80211.ko
│   ├── mac80211.ko
│   ├── rt2800usb.ko  (+ rt2x00usb.ko, rt2x00lib.ko, rt2800lib.ko)
│   ├── rtl8xxxu.ko
│   ├── ath9k_htc.ko  (+ ath9k_hw.ko, ath9k_common.ko, ath.ko)
│   ├── btusb.ko
│   ├── rtl8812au.ko
│   ├── rtl8188eu.ko
│   └── ...
├── Image / Image.gz      # image noyau GKI (référence)
├── Module.symvers        # symboles pour rebuild de modules externes
├── System.map
└── .config               # config effective
```

## Déploiement (rappel des contraintes)

`CONFIG_MODVERSIONS=y` : chaque `.ko` porte un vermagic lié à la version et à la
config exacte du noyau. Un module compilé contre `gki_defconfig` local ne se
chargera sur le device que si son noyau a un vermagic compatible. En pratique :

- **Magisk/KernelSU** : module avec `insmod` au boot. Vérifier la compatibilité
  vermagic avec `modinfo` sur le device, ou recompiler contre le noyau exact du
  device (récupérer `Module.symvers` + `.config` du build LineageOS lynx).
- **Rebuild GKI custom** : intégrer le fragment au build LineageOS lynx et
  flasher `boot.img`/`vendor_boot`.

## Étapes restantes (hors scope de ce dépôt)

- Fourniture du rootfs NetHunter (séparé, côté Kali).
- Signature/chargement des modules sur le device réel.
- Validation matérielle (monitor mode, injection, HID) sur un lynx déverrouillé.
