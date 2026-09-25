# Pilotes out-of-tree

Les pilotes suivants ne sont pas dans l'arbre GKI `kernel/common` et sont
compilés comme modules externes contre le noyau GKI :

| Pilote | Carte | Source | Statut |
|---|---|---|---|
| `rtl8812au` | RTL8812AU / RTL8811AU (Panda Wireless PAU09) | https://github.com/aircrack-ng/rtl8812au | **BLOQUÉ** (voir ci-dessous) |
| `rtl8188eu` | RTL8188EUS (USB 2.4 GHz) | https://github.com/aircrack-ng/rtl8188eus | **BLOQUÉ** (voir ci-dessous) |

`build.sh` clone ces dépôts dans `drivers/` (shallow) puis tente de les
compiler (non bloquant). Un échec n'affecte pas les modules in-tree.

## Pourquoi out-of-tree

- `rtl8812au` n'a jamais été intégré au mainline (le support RTL8821AU/8812AU
  mainline reste partiel via `rtw88`/`rtw89`, sans injection fiable).
- `rtl8188eu` est un chipset distinct du `rtl8xxxu` in-tree (qui couvre
  8188au/8192cu/8192eu). Le driver aircrack-ng fournit l'injection.

## Statut de compilation (GKI 6.12) — HONNÊTE

Ces deux drivers ne compilent **pas** nativement contre le noyau GKI 6.12 avec
clang récent (LLVM 22), pour trois raisons cumulées :

1. **FORTIFY_SOURCE** (`CONFIG_FORTIFY_SOURCE=y` dans GKI). Le code utilise des
   membres tableau de taille zéro (`u8 data[0]`, `u8 buf_star[]`) et des
   `memcpy` qui déclenchent la vérification `__write_overflow_field` :
   ```
   include/linux/fortify-string.h:571: error: call to '__write_overflow_field'
   declared with 'warning' attribute: detected write beyond size of field ...
   [-Werror,-Wattribute-warning]
   ```
2. **Warnings devenus erreurs** (`-Werror` GKI) : `-Wuninitialized`,
   `-Warray-bounds` sur les tableaux `u8 data[0]`.
3. **Flags GCC-only** dans leur Makefile (`-Wno-stringop-overread`), rejetés
   par clang 22.

### Invocation de build utilisée

```bash
make -C drivers/rtl8812au ARCH=arm64 LLVM=1 \
  CONFIG_PLATFORM_ANDROID_ARM64=y CONFIG_PLATFORM_I386_PC=n \
  KSRC=$PWD/kernel/common O=$PWD/out \
  USER_EXTRA_CFLAGS="-Wno-uninitialized -Wno-unknown-warning-option \
                     -Wno-array-bounds -Wno-address-of-packed-member" \
  modules
```

Cette commande passe les warnings mais bloque sur FORTIFY_SOURCE.

### Pistes de correctif (étapes restantes)

1. **Fork maintenu** : utiliser `morrownr/8812au` (et `morrownr/8812cu` /
   `morrownr/8188gu`), qui patchent les problèmes FORTIFY et sont testés
   jusqu'aux noyaux 6.x. Privilégier cette voie.
2. **Patch FORTIFY** : remplacer les `u8 data[0]` par des vrais flexible array
   members (`u8 data[]`) et utiliser `struct_group()` / tailles correctes dans
   les `memcpy` incriminés.
3. **Désactiver FORTIFY** localement : `CONFIG_FORTIFY_SOURCE=n` dans le
   fragment (déconseillé : affaiblit la sécurité et diverge du GKI).

## Modules in-tree équivalents déjà couverts

Sans ces deux drivers, les capacités WiFi USB suivantes restent disponibles via
les modules in-tree produits par ce dépôt :

- RT5370 / RT3070 (Panda PAU0D / PAU07) → `rt2800usb.ko`
- RTL8188AU / RTL8192CU/EU → `rtl8xxxu.ko`
- AR9271 → `ath9k_htc.ko`
