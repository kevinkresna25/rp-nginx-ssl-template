#!/usr/bin/env bash
set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_NAME="rp-nginx-ssl"

detect_compose_cmd() {
  if command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
  elif docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  else
    echo "[ERROR] docker compose / docker-compose tidak ditemukan." >&2
    exit 1
  fi
}

COMPOSE_CMD="$(detect_compose_cmd)"

if ! docker ps --format '{{.Names}}' | grep -qx "${SERVICE_NAME}"; then
  echo "[WARN] Container ${SERVICE_NAME} belum berjalan. Akan mencoba restart via compose tetap."
fi

# Uji konfigurasi di container yang sedang jalan (jika ada)
if docker ps --format '{{.Names}}' | grep -qx "${SERVICE_NAME}"; then
  echo "[INFO] Menguji konfigurasi Nginx di container ${SERVICE_NAME}..."
  if ! docker exec "${SERVICE_NAME}" nginx -t; then
    echo "[ERROR] nginx -t gagal. Periksa file .conf kamu sebelum restart." >&2
    exit 1
  fi
fi

echo "[INFO] Restart service ${SERVICE_NAME}..."
( cd "${COMPOSE_DIR}" && ${COMPOSE_CMD} restart "${SERVICE_NAME}" )

echo "[OK] Restart selesai."
