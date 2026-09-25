# Pilotes out-of-tree

Les pilotes suivants ne sont pas dans l'arbre GKI `kernel/common` et sont
compilés comme modules externes (`make M=... modules`) contre le noyau GKI :

| Pilote | Carte | Source | Notes |
|---|---|---|---|
| `rtl8812au` | RTL8812AU / RTL8811AU (Panda Wireless PAU09) | https://github.com/aircrack-ng/rtl8812au | driver aircrack-ng, dual-band, monitor + injection |
| `rtl8188eu` | RTL8188EUS (USB 2.4 GHz) | https://github.com/aircrack-ng/rtl8188eus | `rtl8xxxu` in-tree ne couvre pas le 8188eu |

`build.sh` clone ces dépôts dans `drivers/` (shallow) puis les compile. Un
échec sur l'un d'eux est non bloquant pour le reste du build.

## Pourquoi out-of-tree

- `rtl8812au` n'a jamais été intégré au mainline (le support RTL8821AU/8812AU
  mainline reste partiel via `rtw88`/`rtw89`, sans injection fiable).
- `rtl8188eu` est un chipset distinct du `rtl8xxxu` in-tree (qui couvre
  8188au/8192cu/8192eu). Le driver aircrack-ng fournit l'injection.

## Recompilation manuelle

```bash
# après un premier ./build.sh qui a produit out/ + Module.symvers
make -C kernel/common O=out ARCH=arm64 LLVM=1 M=drivers/rtl8812au modules
```
