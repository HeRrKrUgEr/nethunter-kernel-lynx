# TRIM_UNUSED_KSYMS — risque « Unknown symbol » sur les drivers out-of-tree

## Contexte

Le build GKI officiel (celui qui tourne sur le device) active
`CONFIG_TRIM_UNUSED_KSYMS=y` : seuls les symboles figurant dans la liste KMI GKI
sont exportés par `vmlinux`. Tout symbole hors liste est supprimé de la table
d'export, et un module qui le référence échoue à l'insmod avec
`Unknown symbol: <nom>`.

Ce repo construit les modules **sans** trim (le `Module.symvers` est donc
complet), car on ne reproduit pas le build officiel (pas de `kernel/build`,
pas de liste KMI générée par l'outillage ABI). Il faut donc vérifier à la main
que les drivers out-of-tree ne référencent aucun symbole vmlinux hors KMI.

## Méthode d'analyse

```sh
python3 analyze-trim.py   # (à la racine du répertoire de build nethunter-lynx)
```

Le script compare les symboles `U` de `88XXau.ko` / `8188eu.ko` (via `llvm-nm -u`)
à :
- `System.map` (symboles vmlinux),
- `Module.symvers` (exports des modules in-tree),
- la KMI GKI = `android/abi_gki_aarch64` + `android/abi_gki_aarch64_pixel`
  (listes texte) + `android/abi_gki_aarch64.stg` (ABI complète, format STG).

## Résultat (build LTO, sept 2026)

Trois symboles vmlinux référencés par les drivers sont **hors KMI GKI** :

| Symbole | 88XXau | 8188eu | Emplacement |
|---|---|---|---|
| `filp_open` | oui | oui | `core/rtw_wlan_util.c` (lecture `/data/misc/wifi/wpa_supplicant.conf`) et `os_dep/osdep_service.c` (`rtw_retrive_from_file`/`rtw_store_to_file`) |
| `kernel_read` | oui | oui | `os_dep/osdep_service.c` |
| `kernel_write` | oui | non | `os_dep/osdep_service.c` |

Ces trois symboles sont absents de `abi_gki_aarch64.stg` (0 occurrence). GKI ne
les exporte pas volontairement (API d'I/O fichier générique, jugées dangereuses
pour des modules vendor ; l'alternative propre `request_firmware` EST dans la
KMI).

## Conséquence

Si le noyau du device trime ces symboles (ce qui est le cas d'un build GKI
officiel), l'insmod des drivers échouera avec `Unknown symbol: filp_open`
(et `kernel_read`/`kernel_write`), **même après le correctif LTO**.

## Correctif prévu (suivi)

1. **Chemin `wpa_supplicant.conf`** (`rtw_wlan_util.c`) : la lecture est déjà
   optionnelle — si `filp_open` échoue, la fonction retourne des valeurs par
   défaut (`cipher array`). Stuber ce bloc (ou le garder sous `#ifdef`) supprime
   `filp_open`/`kernel_read` de ce chemin sans perte fonctionnelle pour
   NetHunter (qui ne parse pas wpa_supplicant.conf).
2. **Helpers `rtw_retrive_from_file`/`rtw_store_to_file`** (`osdep_service.c`) :
   remplacer `filp_open`+`kernel_read`/`kernel_write` par `request_firmware`
   (dans la KMI GKI) là où il s'agit de charger du firmware/EEPROM ; ou stuber
   les appels si la fonctionnalité (config/efuse persistée sur fichier) n'est
   pas utilisée par NetHunter.
3. Recompiler les deux drivers, re-vérifier `llvm-nm -u` (plus aucun symbole
   hors KMI), re-empaqueter.

## Vérification finale

```sh
llvm-nm -u 88XXau.ko | grep -E 'filp_open|kernel_read|kernel_write'
# => aucune sortie attendue après correctif
```
