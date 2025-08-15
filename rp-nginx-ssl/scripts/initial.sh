#!/usr/bin/env bash

DHPARAM_FILE="../nginx/dhparam.pem"
CONF_DIR="../nginx/conf"

# === 1. Cek & buat dhparam.pem ===
if [[ -f "$DHPARAM_FILE" ]]; then
    echo "[OK] File $DHPARAM_FILE sudah ada."
else
    echo "[INFO] File $DHPARAM_FILE belum ada, membuat sekarang..."
    mkdir -p "$(dirname "$DHPARAM_FILE")"
    openssl dhparam -out "$DHPARAM_FILE" 2048
    if [[ $? -eq 0 ]]; then
        echo "[OK] dhparam.pem berhasil dibuat."
    else
        echo "[ERROR] Gagal membuat dhparam.pem" >&2
        exit 1
    fi
fi

# === 2. Cek .conf selain default.conf ===
if [[ ! -d "$CONF_DIR" ]]; then
    echo "[ERROR] Folder $CONF_DIR tidak ditemukan." >&2
    exit 1
fi

# Cari semua .conf selain default.conf
OTHER_CONF=$(find "$CONF_DIR" -type f -name "*.conf" ! -name "default.conf")

if [[ -n "$OTHER_CONF" ]]; then
    echo "[OK] Ditemukan file .conf selain default.conf:"
    echo "$OTHER_CONF"
    echo "[INFO] Persiapan sudah selesai ✅"
else
    echo "[WARN] Tidak ada file .conf selain default.conf di $CONF_DIR."
    echo "[INFO] Persiapan belum lengkap."
fi
