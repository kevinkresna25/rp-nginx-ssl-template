#!/usr/bin/env bash
set -euo pipefail

DEFAULT_EMAIL=""

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

echo "Masukkan domain (-d). Bisa lebih dari satu, pisahkan dengan koma atau spasi."
read -rp "Domain: " DOMAINS_INPUT
if [[ -z "${DOMAINS_INPUT:-}" ]]; then
  echo "[ERROR] Domain tidak boleh kosong." >&2
  exit 1
fi

read -rp "Email (-m) [default: ${DEFAULT_EMAIL}]: " EMAIL_INPUT
EMAIL="${EMAIL_INPUT:-$DEFAULT_EMAIL}"
if [[ -z "${EMAIL}" ]]; then
  echo "[ERROR] Email tidak boleh kosong." >&2
  exit 1
fi

# Normalisasi domain → array [-d domain1 -d domain2 ...]
DOMAINS_INPUT="${DOMAINS_INPUT//,/ }"
read -r -a DOMAINS_ARR <<< "$DOMAINS_INPUT"
DOMAIN_FLAGS=()
for d in "${DOMAINS_ARR[@]}"; do
  DOMAIN_FLAGS+=(-d "$d")
done

COMPOSE_CMD="$(detect_compose_cmd)"

BASE_ARGS=(certonly
  --webroot --webroot-path /var/www/certbot
  --non-interactive
  -m "$EMAIL"
  --agree-tos --no-eff-email
)

echo "[INFO] Menjalankan dry-run (staging) untuk domain: ${DOMAINS_ARR[*]}"
set +e
${COMPOSE_CMD} run --rm certbot "${BASE_ARGS[@]}" "${DOMAIN_FLAGS[@]}" --dry-run
DRY_STATUS=$?
set -e

if [[ $DRY_STATUS -eq 0 ]]; then
  echo "[OK] Dry-run sukses. Melanjutkan request sertifikat PRODUKSI..."
  ${COMPOSE_CMD} run --rm certbot "${BASE_ARGS[@]}" "${DOMAIN_FLAGS[@]}"
  PROD_STATUS=$?
  if [[ $PROD_STATUS -eq 0 ]]; then
    echo "[OK] Sertifikat produksi berhasil dibuat."
    echo "Lokasi: ./rp-nginx-ssl/certbot/etc/live/<domain_utama>/"
    echo "Ingat: ganti config ke tahap HTTPS (1second_step.1conf) lalu restart Nginx:"
    echo "  rp-nginx-ssl/scripts/restart.sh"
  else
    echo "[ERROR] Gagal request sertifikat produksi." >&2
    exit $PROD_STATUS
  fi
else
  echo "[ERROR] Dry-run gagal. Periksa konfigurasi tahap-1 (HTTP + ACME) & akses port 80." >&2
  exit $DRY_STATUS
fi
