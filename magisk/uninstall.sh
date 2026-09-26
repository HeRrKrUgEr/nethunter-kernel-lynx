#!/system/bin/sh
# uninstall.sh — Kali NetHunter modules (Pixel 7a / lynx)
# Décharge les modules chargés (best-effort) et supprime le journal.
# Les modules sont de toute façon déchargés au reboot.

LOG=/data/local/tmp/nethunter-modules.log

for m in 8188eu 88XXau rtl8xxxu hci_uart btusb \
         ath9k_htc ath9k_common ath9k_hw \
         rt2800usb rt2800lib rt2x00usb rt2x00lib \
         mac80211 cfg80211; do
  rmmod "$m" 2>/dev/null
done

rm -f "$LOG" 2>/dev/null
exit 0
