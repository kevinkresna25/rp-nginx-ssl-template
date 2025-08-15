#!/usr/bin/env bash
set -euo pipefail

# === Paths ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONF_DIR="${ROOT_DIR}/nginx/conf"
TEMPLATE_STEP1="${CONF_DIR}/1first_step.1conf"
TEMPLATE_STEP2="${CONF_DIR}/1second_step.1conf"
RESTART_SCRIPT="${SCRIPT_DIR}/restart.sh" # optional

# === Defaults ===
STEP="" # 1 | 2
DOMAIN=""
UPSTREAM_NAME=""
UPSTREAM_PORT=""
OVERWRITE="false"
RELOAD="ask" # ask | yes | no
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

usage() {
  cat <<EOF
Pemakaian:
  $(basename "$0") [opsi]

Opsi:
  -d, --domain <nama>        Domain, contoh: ctf.thelol.me
  -u, --upstream <nama>      Nama container upstream, contoh: web-test
  -p, --port <port>          Port upstream (default: 80)
  -s, --step <1|2>           Pakai template tahap 1 (HTTP) atau tahap 2 (HTTPS). Default: 1
      --force                Overwrite jika <domain>.conf sudah ada
      --reload <yes|no>      Langsung restart Nginx setelah generate (default: tanya)
  -h, --help                 Tampilkan bantuan

Contoh:
  $(basename "$0") -d ctf.thelol.me -u web-test -p 80 -s 1 --reload yes
  $(basename "$0") --domain api.thelol.me --upstream api-service --port 8080 --step 2 --force
EOF
}

# === Parse args ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--domain) DOMAIN="${2:-}"; shift 2;;
    -u|--upstream) UPSTREAM_NAME="${2:-}"; shift 2;;
    -p|--port) UPSTREAM_PORT="${2:-}"; shift 2;;
    -s|--step) STEP="${2:-}"; shift 2;;
    --force) OVERWRITE="true"; shift;;
    --reload) RELOAD="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "[WARN] Opsi tidak dikenali: $1"; usage; exit 1;;
  esac
done

# === Interactive fallback ===
if [[ -z "${DOMAIN}" ]]; then
  read -rp "Masukkan domain: " DOMAIN
fi
if [[ -z "${UPSTREAM_NAME}" ]]; then
  read -rp "Nama container upstream: " UPSTREAM_NAME
fi
if [[ -z "${UPSTREAM_PORT}" ]]; then
  read -rp "Port upstream [80]: " UPSTREAM_PORT
  UPSTREAM_PORT="${UPSTREAM_PORT:-80}"
fi
if [[ -z "${STEP}" ]]; then
  read -rp "Pilih step [1/2] (default 1): " STEP
  STEP="${STEP:-1}"
fi

# === Validasi dasar ===
if [[ -z "${DOMAIN}" || -z "${UPSTREAM_NAME}" ]]; then
  echo "[ERROR] domain dan upstream wajib diisi." >&2
  exit 1
fi
if [[ "${STEP}" != "1" && "${STEP}" != "2" ]]; then
  echo "[ERROR] --step harus 1 atau 2." >&2
  exit 1
fi

# === Pilih template ===
TEMPLATE="${TEMPLATE_STEP1}"
if [[ "${STEP}" == "2" ]]; then
  TEMPLATE="${TEMPLATE_STEP2}"
fi
if [[ ! -f "${TEMPLATE}" ]]; then
  echo "[ERROR] Template tidak ditemukan: ${TEMPLATE}" >&2
  exit 1
fi

# === Output file ===
OUT_CONF="${CONF_DIR}/${DOMAIN}.conf"
if [[ -f "${OUT_CONF}" && "${OVERWRITE}" != "true" ]]; then
  echo "[ERROR] File sudah ada: ${OUT_CONF}. Gunakan --force untuk overwrite." >&2
  exit 1
fi

# === Jika step 2, cek sertifikat sudah ada (peringatan saja) ===
if [[ "${STEP}" == "2" ]]; then
  CERT_BASE="${ROOT_DIR}/certbot/etc/live/${DOMAIN}"
  if [[ ! -f "${CERT_BASE}/fullchain.pem" || ! -f "${CERT_BASE}/privkey.pem" ]]; then
    echo "[WARN] Sertifikat untuk ${DOMAIN} belum ditemukan di ${CERT_BASE}."
    echo "       Pastikan sudah menjalankan registrasi SSL (regisSSL.sh) dan berhasil."
  fi
fi

# === Generate file dari template ===
mkdir -p "${CONF_DIR}"
# Ganti domain.com dan container_name:3000
sed \
  -e "s/domain\.com/${DOMAIN}/g" \
  -e "s#container_name:3000#${UPSTREAM_NAME}:${UPSTREAM_PORT}#g" \
  "${TEMPLATE}" > "${OUT_CONF}"

echo "[OK] CONFIG dibuat: ${OUT_CONF}"
echo "     upstream → ${UPSTREAM_NAME}:${UPSTREAM_PORT}"
echo "     step     → ${STEP}"

# === Reload/Restart ===
compose_cmd="$(detect_compose_cmd)"
do_restart() {
  # Pakai restart.sh kalau ada, supaya konsisten
  if [[ -x "${RESTART_SCRIPT}" ]]; then
    "${RESTART_SCRIPT}"
  else
    (cd "${ROOT_DIR}" && ${compose_cmd} restart "${SERVICE_NAME}")
  fi
}

case "${RELOAD}" in
  yes|YES|y|Y)
    do_restart
    echo "[OK] Nginx direstart."
    ;;
  no|NO|n|N)
    echo "[INFO] Lewati restart. Jalankan manual jika perlu."
    ;;
  ask|ASK|*)
    read -rp "Restart Nginx sekarang? [y/N]: " ANS
    if [[ "${ANS:-N}" =~ ^[Yy]$ ]]; then
      do_restart
      echo "[OK] Nginx direstart."
    else
      echo "[INFO] Restart dilewati."
    fi
    ;;
esac
