# rp-nginx-ssl-template

Template praktis untuk men-deploy **reverse proxy Nginx + SSL (Let’s Encrypt/Certbot)** dengan alur dua tahap (HTTP → minta sertifikat → HTTPS), plus **static site** untuk pengujian.

---

## Fitur

* Reverse proxy Nginx siap **HTTPS** (Let’s Encrypt, mode **webroot**).
* **Template config dua tahap**:

  * `1first_step.1conf` → HTTP + ACME challenge.
  * `1second_step.1conf` → HTTPS + redirect 80→443.
* Skrip utilitas:

  * `initial.sh` (inisialisasi dhparam + cek konfigurasi),
  * `set-conf.sh` (generate vhost dari template, interaktif/CLI),
  * `regisSSL.sh` (dry-run → produksi otomatis jika sukses),
  * `restart.sh` (restart service Nginx via Docker Compose).
* Contoh **static site** (`web-test`) untuk uji routing/proxy.
* Struktur log & sertifikat rapi di volume terpisah.
* `.gitattributes` untuk konsistensi **LF** (Linux EOL).

---

## Struktur Repo

```
.
├── .gitattributes
├── README.md
├── rp-nginx-ssl
│   ├── certbot
│   │   ├── etc               # Sertifikat Let's Encrypt
│   │   └── www               # Webroot ACME challenge
│   ├── docker-compose.yml    # Nginx + Certbot (join ke network: web-net)
│   ├── nginx
│   │   ├── conf
│   │   │   ├── 1first_step.1conf    # Template tahap 1 (HTTP + ACME)
│   │   │   ├── 1second_step.1conf   # Template tahap 2 (HTTPS + redirect)
│   │   │   └── default.conf         # Default fallback
│   │   └── log               # Log Nginx
│   └── scripts
│       ├── initial.sh        # Buat dhparam + cek .conf
│       ├── regisSSL.sh       # Certbot: dry-run → produksi jika sukses
│       ├── restart.sh        # Restart Nginx (docker compose restart)
│       └── set-conf.sh       # Generate vhost dari template (step 1/2)
└── web-test
    ├── docker-compose.yml    # Static site contoh (membuat network web-net otomatis)
    ├── Dockerfile
    └── www/…                 # HTML/CSS/JS
```

---

## Prasyarat

* DNS `A/AAAA` untuk domain/subdomain **sudah mengarah** ke server ini.
* Port **80** dan **443** **terbuka** di firewall/server.
* Docker & Docker Compose terpasang.

> **Catatan jaringan:** `web-test/docker-compose.yml` sudah mendefinisikan network `web-net` (bridge). Jalankan `web-test` terlebih dahulu agar network `web-net` otomatis dibuat, lalu `rp-nginx-ssl` dapat join ke network tersebut.

---

## Quick Start (end-to-end)

Contoh: upstream target = container **`web-test`** port **80**.

1. **Jalankan upstream (`web-test`)** – (membuat network `web-net` otomatis)

```bash
cd web-test
docker compose up -d --build
```

2. **Inisialisasi**

```bash
cd ../rp-nginx-ssl/scripts
./initial.sh
```

* Membuat `nginx/dhparam.pem` jika belum ada.
* Mengecek `.conf` selain `default.conf`.

3. **Jalankan reverse proxy (Nginx + Certbot)**

```bash
cd ..
docker compose up -d
```

4. **Aktifkan Tahap 1 (HTTP + ACME)**
   Gunakan mode **interaktif** (tanpa argumen) **atau** CLI:

**Interaktif (praktis):**

```bash
./set-conf.sh
# isi: domain, upstream (container), port (default 80), pilih step=1, konfirmasi restart
```

**CLI (langsung):**

```bash
./set-conf.sh -d your.domain.tld -u web-test -p 80 -s 1 --reload yes
```

5. **Registrasi SSL (Let’s Encrypt)**
   Skrip akan menjalankan **dry-run**; jika sukses → otomatis request **produksi**.

```bash
./regisSSL.sh
# masukkan domain (bisa banyak, pisahkan spasi/koma) & email (punya default)
```

Sertifikat tersimpan di:

```
rp-nginx-ssl/certbot/etc/live/<domain_pertama>/
```

6. **Switch ke Tahap 2 (HTTPS + redirect 80→443)**
   (Overwrite vhost domain menjadi versi HTTPS)

* **Interaktif:** jalankan `./set-conf.sh` dan pilih **step=2**.
* **CLI:**

```bash
./set-conf.sh -d your.domain.tld -u web-test -p 80 -s 2 --force --reload yes
```

7. **Verifikasi**

```bash
curl -I http://your.domain.tld     # → 301 ke https
curl -I https://your.domain.tld    # → 200 OK
```

---

## Menambah Domain/Subdomain Baru

Ulangi **Tahap 1 → Registrasi SSL → Tahap 2** untuk setiap domain:

```bash
# Tahap 1
./set-conf.sh -d sub.domain.tld -u web-test -p 80 -s 1 --reload yes

# Registrasi SSL
./regisSSL.sh        # isi sub.domain.tld

# Tahap 2
./set-conf.sh -d sub.domain.tld -u web-test -p 80 -s 2 --force --reload yes
```

Atau gunakan `./set-conf.sh` **tanpa parameter** untuk mode interaktif.

---

## Referensi Skrip

### `scripts/initial.sh`

* Membuat `nginx/dhparam.pem` (2048) jika belum ada.
* Mengecek `.conf` selain `default.conf`.

### `scripts/set-conf.sh`

Generate vhost dari template tahap **1/2**, ganti:

* `domain.com` → `your.domain.tld`
* `container_name:3000` → `<upstream_name>:<upstream_port>`

**Mode interaktif**: jalankan tanpa argumen.
**Mode CLI**:

```
set-conf.sh -d <domain> -u <upstream_name> -p <upstream_port> -s <1|2> [--force] [--reload yes|no|ask]
```

Contoh:

```bash
./set-conf.sh -d api.domain.tld -u api-service -p 8080 -s 1 --reload yes
./set-conf.sh -d api.domain.tld -u api-service -p 8080 -s 2 --force --reload yes
```

### `scripts/regisSSL.sh`

* Input **domain** (bisa multi: pisahkan spasi/koma) dan **email** (ada default).
* Jalankan **dry-run**; jika sukses → otomatis request **produksi**.

### `scripts/restart.sh`

* Menguji `nginx -t` (jika container berjalan), lalu:
* `docker compose restart rp-nginx-ssl`.

---

## Contoh Snippet Upstream (di vhost)

```nginx
location / {
    proxy_pass http://web-test:80;     # ganti sesuai service/port upstream
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Host $server_name;
}
```

---

## Troubleshooting

* **ACME gagal (dry-run error)**:

  * DNS domain sudah mengarah ke server ini?
  * Port **80** terbuka dan tidak di-block firewall?
  * Vhost Tahap 1 aktif, dan `/.well-known/acme-challenge/` mengarah ke `/var/www/certbot`?
* **Cek konfigurasi**:
  `docker exec rp-nginx-ssl nginx -t`
* **Reload cepat** (tanpa restart total):
  `docker exec rp-nginx-ssl nginx -s reload`
* **Log**:
  `rp-nginx-ssl/nginx/log/` dan `docker logs rp-nginx-ssl`
* **Let’s Encrypt rate limit**: Gunakan alur dry-run terlebih dulu (skrip sudah otomatis).
* **Line endings**: Repo sudah enforce **LF** via `.gitattributes`.

---

## Referensi

* Blog: **Nginx Reverse Proxy + SSL Let’s Encrypt (Docker)** – Musa Amin
  [https://musaamin.web.id/nginx-reverse-proxy-ssl-lets-encrypt-docker/](https://musaamin.web.id/nginx-reverse-proxy-ssl-lets-encrypt-docker/)

* YouTube: **Nginx Reverse Proxy + SSL Let’s Encrypt (Docker)**
  [https://www.youtube.com/watch?v=kMu8g5uGVRY](https://www.youtube.com/watch?v=kMu8g5uGVRY)

---

## License

MIT © Kevin Kresna, 2025. [MIT License](LICENSE)
