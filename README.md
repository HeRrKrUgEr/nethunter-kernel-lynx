# Kali NetHunter Kernel — Google Pixel 7a (lynx)

Noyau Kali NetHunter pour le **Google Pixel 7a** (codename `lynx`, SoC Google
Tensor G2 / plateforme `gs201`), ciblé pour **Android 14 / noyau 6.1.145**.

> **Cible exacte** : `kernel/common` branche `android14-6.1`, commit
> `edaaac4d5c85` (build GKI `ab16017558`), noyau
> `6.1.145-android14-11-gedaaac4d5c85`. Ce build vise le noyau **Android 14**
> (6.1.145), pas Android 16.

## Objectif

Produire les modules noyau (`.ko`) qui ajoutent les capacités de **pentest
matériel** de Kali NetHunter à un Pixel 7a sous Android 14, en conservant le
noyau GKI d'origine (pas de rebuild du `boot.img`) :

- mac80211 en mode monitor + injection de paquets (natifs mainline depuis 5.7)
- Pilotes de cartes WiFi USB externes : RTL8812AU, RT2800USB (RT5370/RT3070),
  RTL8188EUS/RTL8188AU, ath9k_htc (AR9271)
- Gadget HID (attaques USB HID), gadgetfs / f_hid
- Bluetooth HCI + injection
- USB tethering / RNDIS, gadget USB

## Point critique : GKI

Les Pixel modernes n'utilisent plus le fork `android_kernel_google_gs201`
(arrêté à `lineage-21` = Android 14). Ils utilisent le **noyau Google GKI** :

- Android 14 → `kernel/common` branche `android14-6.1` (ce build, noyau 6.1.145)
- Android 15 → `kernel/common` branche `android15-6.6`
- Android 16 → `kernel/common` branche `android16-6.12`

Le noyau GKI est « gelé » (ABI stable). Toute personnalisation passe par des
**modules chargeables** (`.ko`), chargés via insmod (chroot NetHunter ou module
Magisk/KernelSU). On ne patche pas le noyau.

## Vermagic (le critère de succès)

Les `.ko` sont compilés contre un noyau précis. Le vermagic produit est :

```
6.1.145-android14-11-gedaaac4d5c85 SMP preempt mod_unload modversions aarch64
```

Un module ne se charge QUE sur un noyau de version exactement identique
(`uname -r` du device = `6.1.145-android14-11-gedaaac4d5c85-ab16017558`),
avec les mêmes CRC modversions. Voir `docs/VERMAGIC.md`.

## Build

```bash
./build.sh              # noyau + modules in-tree + pilotes out-of-tree
./build-magisk.sh 6.1.145   # module Magisk installable
```

Prérequis : **clang 17** (LLVM 17.x) — le clang 22 d'Arch est trop récent pour
ce noyau 6.1 (`-Werror` casse libbpf). Voir `docs/BUILD.md`.

## État du projet

Modules in-tree + drivers out-of-tree (`88XXau.ko`, `8188eu.ko`) compilés.
Voir `build.sh`, `configs/nethunter.config`, `docs/BUILD.md`.

## Avertissement

Charger un module noyau custom peut rendre le système instable. Bootloader
déverrouillé requis. Ne jamais relocker le bootloader avec un noyau modifié.
Sauvegardez vos données.
