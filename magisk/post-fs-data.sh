#!/system/bin/sh
# post-fs-data.sh — Kali NetHunter modules (Pixel 7a / lynx)
# Exécuté par Magisk au stade post-fs-data.
# Charge les .ko du noyau GKI 6.12.92 dans l'ordre des dépendances.
# Journal : /data/local/tmp/nethunter-modules.log
#
# ATTENTION : les .ko sont compilés contre un noyau précis (vermagic +
# modversions). Si le noyau du device diffère (version, hash local, config),
# insmod échouera. Voir docs/VERMAGIC.md.

MODDIR=${0%/*}
KO_DIR="$MODDIR/system/lib/modules"
LOG="/data/local/tmp/nethunter-modules.log"

{
  echo "=================================================="
  echo "NetHunter modules — $(date)"
  echo "uname: $(uname -r)"
  echo "KO_DIR=$KO_DIR"
  echo "=================================================="
} >> "$LOG" 2>&1

load() {
  ko="$KO_DIR/$1"
  if [ ! -f "$ko" ]; then
    echo "[ABSENT] $1" >> "$LOG"
    return 0
  fi
  if insmod "$ko" >> "$LOG" 2>&1; then
    echo "[OK]     $1" >> "$LOG"
  else
    echo "[ECHEC]  $1 (voir ligne precedente — vermagic/modversions/dependance)" >> "$LOG"
  fi
}

# 1. Stack cfg80211/mac80211
load cfg80211.ko
load mac80211.ko

# 2. rt2x00 (RT5370/RT3070 — Panda PAU0D/PAU07)
load rt2x00lib.ko
load rt2x00usb.ko
load rt2800lib.ko
load rt2800usb.ko

# 3. ath9k (AR9271)
load ath9k_hw.ko
load ath9k_common.ko
load ath9k_htc.ko

# 4. Bluetooth
load btusb.ko
load hci_uart.ko

# 5. Realtek
load rtl8xxxu.ko
load 88XXau.ko
load 8188eu.ko

echo "fin: $(date)" >> "$LOG"
