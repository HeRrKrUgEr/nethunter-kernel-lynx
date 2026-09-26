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
3. Les pilotes **out-of-tree** (RTL8812AU → `88XXau.ko`, RTL8188EU → `8188eu.ko`)
   en modules `.ko` ;
4. Un **module Magisk** installable (voir `build-magisk.sh`).

Résultat : un jeu de fichiers `.ko` à charger sur le device (via `insmod`
depuis le chroot NetHunter, ou le module Magisk/KernelSU), sans toucher au
`boot.img` GKI.

## Capacités activées

| Capacité | Pilote / config | Statut |
|---|---|---|
| Monitor mode + injection 802.11 | mac80211 + cfg80211 (mainline) | `=m`, natif, aucun patch |
| RTL8812AU (Panda PAU09) | `88XXau.ko` (out-of-tree aircrack-ng) | compilé |
| RT2800USB RT5370/RT3070 (Panda PAU0D/PAU07) | `rt2800usb.ko` (+ rt2x00) | `=m` |
| RTL8188AU / RTL8192CU/EU | `rtl8xxxu.ko` | `=m` |
| RTL8188EUS | `8188eu.ko` (out-of-tree aircrack-ng) | compilé |
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
./build-magisk.sh     # génère output/nethunter-lynx-magisk-6.12.92.zip
```

Prérequis (Arch) :

```bash
sudo pacman -S --needed base-devel git python clang llvm lld bc cpio libelf pahole dtc zip unzip
```

Le build requiert clang + lld récents (LLVM 18+, 22 testé ici) pour compiler un
noyau 6.12. La stack Rust du noyau GKI est désactivée (fragment) car non
nécessaire pour ces modules et pour éviter la dépendance `rustc`/`bindgen`.

Détail : `docs/BUILD.md` (build noyau) et `drivers/README.md` (pilotes
out-of-tree, recette FORTIFY/clang 22).

## Module Magisk

`./build-magisk.sh` assemble un zip installable via l'appli Magisk :

```
module.prop                                (id=nethunter_lynx)
META-INF/com/google/android/update-binary  (installer Magisk standard)
META-INF/com/google/android/updater-script
post-fs-data.sh                            (insmod dans l'ordre des dépendances)
uninstall.sh                               (rmmod best-effort)
system/lib/modules/*.ko                    (126 in-tree + 88XXau.ko + 8188eu.ko)
```

Le `post-fs-data.sh` charge les modules dans cet ordre :
`cfg80211 → mac80211 → rt2x00lib → rt2x00usb → rt2800lib → rt2800usb →
ath9k_hw → ath9k_common → ath9k_htc → btusb → hci_uart → rtl8xxxu →
88XXau → 8188eu`, avec journal dans `/data/local/tmp/nethunter-modules.log`.

## Déploiement sur le device — avertissement vermagic

GKI active `CONFIG_MODVERSIONS=y` et `CONFIG_MODULE_SIG=y`. Un module compilé
contre 6.12.92 ne se charge que sur un noyau de version **exactement
identique** (vermagic + CRC de symboles). Le device LineageOS 23.2 lynx a très
probablement un `uname -r` différent.

**Lire `docs/VERMAGIC.md` avant le test.** En résumé :

1. Vérifier : `adb shell uname -r` vs `modinfo <fichier.ko> | grep vermagic`.
2. Si différent : recompiler contre le noyau exact du device (`.config` +
   `Module.symvers` de LineageOS), patcher la chaîne vermagic à longueur égale,
   ou utiliser KernelSU.

Le bootloader doit être déverrouillé et le device rooté.

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
