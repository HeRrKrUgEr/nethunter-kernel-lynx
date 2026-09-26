# Vermagic, MODVERSIONS et signature — ce qui conditionne le test

Ce document explique pourquoi les modules `.ko` produits ici peuvent ne PAS
se charger tels quels sur le device, et comment le vérifier / corriger.

## Le noyau GKI active trois verrous

Le noyau GKI `android16-6.12` active (visible dans `out/.config`) :

- `CONFIG_MODVERSIONS=y` : chaque symbole exporté reçoit un CRC calculé depuis
  sa signature. Un module compilé contre un `Module.symvers` différent
  échouera avec « disagrees about version of symbol ... ».
- `CONFIG_MODULE_SIG=y` : les modules sont signés. Le noyau refuse un module
  dont la signature est invalide **si** `CONFIG_MODULE_SIG_FORCE=y` (sur un
  device Android de production, c'est souvent le cas). Ici le build signe avec
  une clé jetable `out/certs/signing_key.pem` : elle ne correspond pas à la
  clé du noyau du device.
- `CONFIG_LOCALVERSION` / `CONFIG_LOCALVERSION_AUTO` : la chaîne `uname -r`
  embarque un hash git (`gaff1917ea969` ici) et le suffixe `-4k`. Cette chaîne
  fait partie du **vermagic**.

Le vermagic produit par **ce** build est :

```
6.12.92-4k-gaff1917ea969 SMP preempt mod_unload modversions aarch64
```

Le vermagic du module doit être **strictement égal** à celui du noyau qui
tourne sur le device, sinon `insmod` refuse de charger le module.

## Vérifier la correspondance

Sur le device (via `adb shell`) :

```sh
adb shell uname -r                 # version du noyau qui tourne
adb shell cat /proc/version        # version complète (avec hash, compilateur)
```

Sur l'hôte, pour chaque `.ko` :

```sh
modinfo output/modules/cfg80211.ko | grep -E 'vermagic|scmversion'
```

Si `uname -r` du device ne vaut pas exactement
`6.12.92-4k-gaff1917ea969` (ou que les flags SMP/preempt/modversions
diffèrent), **aucun module ne se chargera** tel quel.

## Ce qui marchera out-of-the-box

Uniquement si le device tourne **exactement** ce noyau :
- même version `6.12.92` + même `CONFIG_LOCALVERSION` (`-4k`) + même hash git
  (`gaff1917ea969`), soit un `uname -r` identique ;
- même `Module.symvers` (donc mêmes CRC de symboles) ;
- `CONFIG_MODULE_SIG_FORCE` désactivé, OU modules re-signés avec la clé du
  device.

Concrètement : le Pixel 7a sous **LineageOS 23.2** a presque sûrement un
`uname -r` différent (LineageOS ajoute son propre localversion, hash et
build number). **Attendre un échec au premier insmod est la norme, pas
l'exception.**

## Les 3 voies si le vermagic diffère

### (a) Recompiler contre le noyau exact du device (voie propre)

Récupérer depuis le device (ou l'arbre LineageOS du build) :

1. `adb pull /proc/config.gz` (ou `zcat /proc/config.gz > .config`) — si le
   noyau n'expose pas config.gz, récupérer le `.config` depuis l'arbre de build
   LineageOS (`out/target/product/lynx/obj/KERNEL_OBJ/.config`).
2. `Module.symvers` depuis le même arbre (`KERNEL_OBJ/Module.symvers`).

Puis recompiler **le noyau et les modules** avec ce `.config` exact (les
modules in-tree) et recompiler les drivers out-of-tree avec ce `Module.symvers`
et ce `.config`. C'est la seule méthode garantie.

### (b) Patcher la chaîne vermagic à longueur égale (rapide, fragile)

La chaîne vermagic est stockée en clair dans le binaire du `.ko`. On peut la
remplacer par celle du device **à condition de garder la même longueur** :

```sh
# lire le vermagic du device
DEV_VERMAGIC="6.12.92-android16-... SMP preempt mod_unload modversions aarch64"
# patcher (même longueur requise)
# python3 -c "remplacer la chaîne dans le .ko par une chaîne de même taille"
```

Limites : ne corrige PAS les CRC de `MODVERSIONS` (le module échouera toujours
si les symboles diffèrent), ni la signature. Utile seulement quand la
différence est purement cosmétique (hash/localversion) avec des CRC identiques.
Aucune garantie.

### (c) KernelSU (tolère mieux les modules)

KernelSU n'applique pas la même politique de signature que les kernels
Android de production et tolère souvent mieux les modules out-of-tree, à
condition que les **CRC de symboles (modversions)** correspondent toujours.
KernelSU fournit aussi `ksud module` pour gérer les modules. C'est la voie la
plus pratique pour du dev/réseau, mais le `Module.symvers` doit quand même
correspondre.

## En résumé

| Situation | Résultat |
|---|---|
| `uname -r` identique + mêmes CRC + sig désactivée | modules chargent tels quels |
| `uname -r` différent (localversion/hash) mais CRC identiques | patch vermagic (b) ou recompile (a) |
| CRC de symboles différents | recompiler (a) obligatoirement, ou KernelSU + recompile |
| signature forcée (MODULE_SIG_FORCE) | re-signer avec la clé du device ou KernelSU |
