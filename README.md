# Kali NetHunter Kernel — Google Pixel 7a (lynx)

Noyau Kali NetHunter pour le **Google Pixel 7a** (codename `lynx`, SoC Google
Tensor G2 / plateforme `gs201`), ciblé pour **LineageOS 23.2 (Android 16)**.

## Méthode retenue : GKI + LKM (modules chargeables)

Ce projet **ne rebuild pas** un fork de noyau constructeur. Le Pixel 7a est un
appareil **GKI** (Generic Kernel Image). Le noyau est celui de Google
`kernel/common`, branche **`android16-6.12`** (le fork `android_kernel_google_gs201`
s'arrête à Android 14 et n'est plus utilisé sous Android 16).

Sous GKI, le noyau est « gelé » (ABI stable / GKI compliance) : toute
personnalisation doit passer par des **modules chargeables (LKM)**, qui est le
seul point d'extension autorisé. Le builder Kali historique
(`kali-nethunter-kernel`) n'est pas applicable : ses patches s'arrêtent au
noyau 5.4, et son patch « mac80211 packet injection » est déjà **upstream**
dans le noyau 6.12 (monitor mode + injection natifs depuis le noyau 5.7).

Ce dépôt construit donc :

1. Le noyau GKI `android16-6.12` (`gki_defconfig`) ;
2. Un **fragment de config** `configs/nethunter.config` qui active, en
   modules `=m`, la stack wireless et les pilotes WiFi/BT/gadget requis ;
3. Les pilotes **out-of-tree** (RTL8812AU, RTL8188EU) en modules `.ko`.

Résultat : un jeu de fichiers `.ko` à charger sur le device (via `insmod` /
`modprobe` depuis le chroot NetHunter, ou un module Magisk/KernelSU), sans
toucher au `boot.img` GKI.

## Capacités activées

| Capacité | Pilote / config | Statut |
|---|---|---|
| Monitor mode + injection 802.11 | mac80211 + cfg80211 (mainline) | `=m`, natif, aucun patch |
| RTL8812AU (Panda PAU09) | `rtl8812au.ko` (out-of-tree aircrack-ng) | `=m` |
| RT2800USB RT5370/RT3070 (Panda PAU0D/PAU07) | `rt2800usb.ko` (+ rt2x00) | `=m` |
| RTL8188AU / RTL8192CU/EU | `rtl8xxxu.ko` | `=m` |
| RTL8188EUS | `rtl8188eu.ko` (out-of-tree aircrack-ng) | `=m` |
| ath9k_htc AR9271 | `ath9k_htc.ko` (+ ath9k_hw/ath9k_common) | `=m` |
| USB HID (BadUSB / DuckHunter) | `USB_CONFIGFS_F_HID` + `f_fs` | `=y` (déjà dans GKI) |
| gadgetfs (HID legacy) | `usb_gadgetfs` | `=y` |
| Bluetooth HCI USB (injection) | `btusb.ko` | `=m` |
| Bluetooth HCI UART | `hci_uart.ko` | `=m` (déjà dans GKI) |
| USB tethering / RNDIS | `USB_CONFIGFS_RNDIS` | `=y` |
| USB tethering NCM/ECM/EEM | configfs | `=y` (déjà dans GKI) |

## Build

```bash
git clone https://github.com/HeRrKrUgEr/nethunter-kernel-lynx.git
cd nethunter-kernel-lynx
./build.sh            # JOBS=4 ./build.sh si RAM limitée
```

Prérequis (Arch) :

```bash
sudo pacman -S --needed base-devel git python clang llvm lld bc cpio libelf pahole dtc zip unzip
```

Le build requiert clang + lld récents (LLVM 18+) pour compiler un noyau
6.12. La stack Rust du noyau GKI est désactivée (fragment) car non nécessaire
pour ces modules et pour éviter la dépendance `rustc`/`bindgen`.

Détail : voir `docs/BUILD.md`.

## Déploiement sur le device

Les `.ko` doivent être chargés sur le **même noyau** que celui qui tourne sur
l'appareil. GKI active `CONFIG_MODVERSIONS=y` et `CONFIG_MODULE_SIG=y` : un
module est signé et versionné (vermagic). Deux voies possibles :

1. **Module Magisk/KernelSU** : déposer les `.ko` dans le module, les charger
   au boot via `post-fs-data.sh` avec `insmod`, après avoir re-signé/vérifié la
   correspondance vermagic avec le noyau du device.
2. **Rebuild complet du noyau GKI du device** (LineageOS 23.2 lynx) avec ces
   pilotes intégrés, et flash d'un `boot.img`/`vendor_boot` custom.

Dans les deux cas le bootloader doit être déverrouillé et le device rooté.

## Avertissement

Flasher/charger un noyau ou des modules custom peut soft-bricker l'appareil.
Bootloader déverrouillé obligatoire. Ne jamais relocker le bootloader avec un
noyau/module custom. Sauvegarder ses données. Ce dépôt ne fournit pas le
rootfs NetHunter (fourni séparément par Kali) : il ne traite que le noyau.

## Sources / références

- Sources GKI : https://android.googlesource.com/kernel/common (`android16-6.12`)
- Builder NetHunter (historique) : https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel
- Doc portage : https://www.kali.org/docs/nethunter/porting-nethunter-kernel-builder/
- Pilotes out-of-tree : https://github.com/aircrack-ng/rtl8812au · https://github.com/aircrack-ng/rtl8188eus
- Device tree LineageOS : https://github.com/LineageOS/android_device_google_lynx (branche `lineage-23.2`)
