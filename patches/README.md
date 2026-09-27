# Patches des drivers out-of-tree

Ces patches sont appliqués par `build.sh` après le clonage des drivers
aircrack-ng, pour corriger les signatures cfg80211 qui ont changé dans le
noyau 6.1 (puncturing Wi-Fi 7 : paramètre `punct_bitmap`).

| Patch | Driver | Ce qu'il corrige |
|---|---|---|
| `rtl8812au-cfg80211-6.1.patch` | rtl8812au (aircrack-ng) | seuil `cfg80211_ch_switch_notify` (4 args) + `cfg80211_ch_switch_started_notify` (6 args) : `KERNEL_VERSION(6,3,0)` → `KERNEL_VERSION(6,1,0)` |
| `rtl8188eu-cfg80211-6.1.patch` | rtl8188eu (aircrack-ng) | seuil `cfg80211_ch_switch_notify` (4 args) : `KERNEL_VERSION(6,3,0)` → `KERNEL_VERSION(6,1,0)` |

## Pourquoi

Les drivers aircrack-ng (rtl8812au v5.6.4.2 de 2019, rtl8188eu v5.3.9 de 2018)
sont figés. Le noyau 6.1 a ajouté `punct_bitmap` (et `count`/`quiet` pour
`*_started_notify`) aux notifications de changement de canal, mais les drivers
gèrent ce cas seulement à partir de `6.3`. Résultat : pour 6.1, ils compilent
l'ancienne variante (3/5 args) et échouent avec « too few arguments ».

Ces patches ne touchent que les seuils `#if` de version, pas la logique.
