# Pilotes out-of-tree

Deux pilotes WiFi USB ne sont pas dans l'arbre GKI `kernel/common` et sont
compilés comme modules externes contre le noyau GKI 6.12 :

| Pilote | Carte | Source (aircrack-ng) | `.ko` produit | Statut |
|---|---|---|---|---|
| `rtl8812au` | RTL8812AU / RTL8811AU (Panda PAU09) | github.com/aircrack-ng/rtl8812au (v5.6.4.2) | `88XXau.ko` | **COMPILE** |
| `rtl8188eu` | RTL8188EUS (USB 2.4 GHz) | github.com/aircrack-ng/rtl8188eus (v5.3.9) | `8188eu.ko` | **COMPILE** |

`build.sh` clone ces dépôts (shallow) puis les compile contre le noyau GKI déjà
présent dans `kernel/common`, en réutilisant l'arbre de build `out/`.

## Pourquoi out-of-tree

- `rtl8812au` n'a jamais été intégré au mainline (le support RTL8821AU/8812AU
  mainline reste partiel via `rtw88`/`rtw89`, sans injection fiable).
- `rtl8188eu` est un chipset distinct du `rtl8xxxu` in-tree. Le driver
  aircrack-ng fournit l'injection.

## Recette de compilation (GKI 6.12 + clang 22)

Ces drivers legacy ne compilent PAS nativement contre un noyau GKI 6.12 récent
(clang 22). Trois problèmes cumulés, et leur correctif :

1. **FORTIFY_SOURCE** (`CONFIG_FORTIFY_SOURCE=y`) : le code utilise des membres
   `u8 data[0]` (zero-length arrays) qui déclenchent `__write_overflow_field`.
   Correctif : `-D__NO_FORTIFY`. Ce define désactive proprement l'inclusion de
   `fortify-string.h` (`kernel/common/include/linux/string.h:389`), sans diverger
   du noyau (c'est la voie utilisée par `lib/string.c` lui-même).
2. **Warnings legacy devenus erreurs** (`-Werror`, `CONFIG_WERROR=y`) : clang 22
   émet une longue série de warnings sur ces codebases (tautological-overlap-
   compare, implicit-fallthrough, parentheses-equality, maybe-uninitialized…).
   Correctif : `-Wno-error` (dégrade les warnings génériques en warnings) +
   `-Wno-uninitialized -Wno-array-bounds -Wno-address-of-packed-member
   -Wno-unknown-warning-option` (ce dernier absorbe le flag GCC-only
   `-Wno-stringop-overread` du Makefile). Les `-Werror=implicit-function-
   declaration` / `-Werror=incompatible-pointer-types` du noyau restent actifs :
   un vrai bug (symbole absent, type incompatible) fera toujours échouer le
   build.
3. **`linux/wlan_plat.h` manquant** : `CONFIG_PLATFORM_ANDROID_ARM64` active
   `-DRTW_ENABLE_WIFI_CONTROL_FUNC`, qui fait inclure cet en-tête supprimé du
   mainline. Correctif : compiler avec `CONFIG_PLATFORM_ARM64_RPI=y` (arm64 +
   `-DCONFIG_IOCTL_CFG80211 -DRTW_USE_CFG80211_STA_EVENT`, sans la glue Android
   legacy). NetHunter utilise nl80211/cfg80211, pas le HAL Android legacy.

### Commande exacte

```bash
make -C drivers/rtl8812au ARCH=arm64 LLVM=1 \
  CONFIG_PLATFORM_ARM64_RPI=y CONFIG_PLATFORM_I386_PC=n \
  KSRC=$PWD/kernel/common O=$PWD/out \
  USER_EXTRA_CFLAGS="-D__NO_FORTIFY -Wno-error -Wno-uninitialized \
    -Wno-unknown-warning-option -Wno-array-bounds -Wno-address-of-packed-member" \
  modules
```

Idem pour `rtl8188eu`.

## Nom des modules produits

- `rtl8812au` → `88XXau.ko` (MODULE_NAME = `88XXau` quand RTL8812A + RTL8821A
  + RTL8814A sont activés ensemble — le défaut).
- `rtl8188eu` → `8188eu.ko`.

## Modules in-tree équivalents déjà couverts

- RT5370 / RT3070 (Panda PAU0D / PAU07) → `rt2800usb.ko`
- RTL8188AU / RTL8192CU/EU → `rtl8xxxu.ko`
- AR9271 → `ath9k_htc.ko`
