# Kali NetHunter Kernel — Google Pixel 7a (lynx)

Noyau Kali NetHunter pour le **Google Pixel 7a** (codename `lynx`, SoC Google Tensor G2 / plateforme `gs201`), ciblé pour **LineageOS 23.2 (Android 16)**.

## Objectif

Produire un noyau flashable (image `boot.img` ou archive AnyKernel3) qui ajoute les capacités de **pentest matériel** de Kali NetHunter à un Pixel 7a sous LineageOS 23.2 :

- mac80211 en mode monitor + injection de paquets (patchs NetHunter)
- Pilotes de cartes WiFi USB externes : RTL8812AU, RT2800USB (RT5370/RT3070), RTL8188EUS/RTL8188AU, ath9k_htc (AR9271)
- Gadget HID (attaques USB HID), gadgetfs / f_hid
- Bluetooth HCI + injection
- USB tethering / RNDIS, gadget USB

## Point critique : GKI

Les Pixel modernes sous Android 15/16 n'utilisent plus le fork `android_kernel_google_gs201` (arrêté à `lineage-21` = Android 14). Ils utilisent le **noyau Google GKI** :

- Android 15 → `kernel/common` branche `android15-6.6`
- Android 16 → `kernel/common` branche `android16-6.12`

Ce projet construit depuis `android16-6.12`, avec les modules/configs device-specific issus de `device/google/lynx-kernel`.

## État du projet

**En cours de construction.** Voir `build.sh`, `patches/`, `defconfig/` et le README détaillé (`docs/BUILD.md`) pour la procédure pas-à-pas.

## Avertissement

Flasher un noyau custom peut soft-bricker l'appareil. Bootloader déverrouillé obligatoire. Ne jamais relocker le bootloader avec ce noyau. Sauvegardez vos données.
