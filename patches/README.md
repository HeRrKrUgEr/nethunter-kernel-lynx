# Patches

Aucun patch du noyau n'est appliqué dans ce projet.

Raison : le Pixel 7a utilise le noyau GKI `android16-6.12`. Les patches
historiques NetHunter couvraient des noyaux anciens (3.04 → 5.4) et corrigeaient
principalement :

1. **mac80211 packet injection** — upstream depuis le noyau 5.7. Inutile sur 6.12.
2. **HID gadget / f_hid** — upstream depuis longtemps ; `USB_CONFIGFS_F_HID=y`
   et `USB_CONFIGFS_F_FS=y` sont déjà actives dans `gki_defconfig`.
3. **bluetooth / btusb** — mainline ; on active simplement `CONFIG_BT_HCIBTUSB=m`.

Tout est donc géré par configuration (`configs/nethunter.config`), pas par
patch. Ce répertoire est conservé pour d'éventuels futurs patches correctifs
spécifiques à `lynx`.
