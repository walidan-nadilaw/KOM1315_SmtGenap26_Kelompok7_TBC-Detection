# Sistem Manajemen Lab & Skrining Awal Tuberkulosis (TBC)

> **Projek Akhir — Keamanan Informasi | Kelompok 7 | Kelas K1 | 2026**

Sistem backend untuk manajemen laboratorium dan skrining awal Tuberkulosis dari citra histopatologi. Dibangun dengan fokus pada **keamanan informasi data klinis pasien** sebagai studi kasus penerapan prinsip-prinsip keamanan informasi dalam aplikasi medis nyata.

---

## 📋 Daftar Isi

- [Gambaran Umum](#gambaran-umum)
- [Anggota Kelompok](#anggota-kelompok)
- [Struktur Repositori](#struktur-repositori)
- [Tech Stack](#tech-stack)
- [Cara Menjalankan](#cara-menjalankan)
- [Fitur Keamanan Informasi](#fitur-keamanan-informasi)
- [Alur Kerja Sistem](#alur-kerja-sistem)
- [API Endpoints](#api-endpoints)
- [Lisensi](#lisensi)

---

## Gambaran Umum

Sistem ini adalah project untuk mata kuliah **Keamanan Informasi**. Sistem menangani data sensitif berupa:

- Data identitas pasien (NIK, nomor BPJS)
- Citra histopatologi medis
- Hasil analisis AI dan validasi dokter
- Laporan klinis berformat digital

Aktor & Peran

| Role                | Tugas                                                     |
| ------------------- | --------------------------------------------------------- |
| `OPERATOR_LAB`    | Upload citra histopatologi, kelola data pasien & kasus    |
| `DOKTER_PATOLOGI` | Review & validasi hasil skrining AI, beri komentar klinis |
| `ADMIN_AI`        | Monitoring sistem AI                                      |

---

## Anggota Kelompok

| Nama                | NIM         |
| ------------------- | ----------- |
| Walid Nadirul Ahnaf | G6401231109 |
| Yasir               | G6401231091 |
| Cokorda Satria      | G6401231064 |

---

## Struktur Repositori

```
Projek Akhir KI/
├── 01_Proposal_&_Analisis/      # Proposal teknis & threat modelling
├── 02_Design_Documents/         # ERD, architecture diagram, testing plan
│   ├── ERD.png
│   ├── Architecture_Diagram.pdf
│   └── Testing_Plan.pdf
├── 03_Source_Code/
│   ├── backend/                 # REST API (Node.js + TypeScript + Express)
│   │   ├── prisma/              # schema.prisma, migrasi, seed
│   │   ├── scripts/             # generate-rsa-keys.ts (kunci tanda tangan digital)
│   │   └── src/
│   │       ├── config/          # prisma, supabase, swagger
│   │       ├── routes/          # Definisi endpoint per domain
│   │       ├── controller/      # Handler HTTP
│   │       ├── services/        # Business logic & keamanan domain
│   │       │   └── storage/     # Abstraksi storage (Supabase)
│   │       ├── validations/     # Zod schema per domain
│   │       ├── middlewares/     # authenticate/authorize, validate, rate-limit, error-handler
│   │       ├── utils/           # jwt, hash, crypto (AES), signature (RSA), audit, access
│   │       └── __tests__/       # Unit test (Vitest)
│   ├── database/                # Mirror schema.prisma + migrasi + seed
│   └── digital_signature/       # Modul referensi tanda tangan digital
├── 04_Reports_&_Paper/          # Laporan akhir, progress report, paper ilmiah
└── 05_Testing/                  # Hasil unit testing
```

---

## Tech Stack

| Layer         | Teknologi                                    | Versi    |
| ------------- | -------------------------------------------- | -------- |
| Runtime       | Node.js (ES Modules)                         | LTS      |
| Language      | TypeScript (strict mode)                     | ^6.0     |
| Framework     | Express                                      | ^5.2     |
| ORM           | Prisma                                       | ^6.19    |
| Database      | PostgreSQL via Supabase                      | —       |
| Auth          | JWT (`jsonwebtoken`) + bcrypt              | —       |
| Validation    | Zod                                          | ^4.3     |
| Rate Limiting | express-rate-limit                           | ^8.5     |
| Kriptografi   | Node`crypto` (AES-256, RSA-2048, SHA-256)  | built-in |
| API Docs      | Swagger (swagger-jsdoc + swagger-ui-express) | —       |
| Testing       | Vitest                                       | ^4.1     |
| Storage       | Supabase Storage                             | —       |

### Environment Variables

```env
# Server
PORT=5001

# Database (Supabase / PostgreSQL)
DATABASE_URL="postgresql://...@pooler.supabase.com:6543/postgres?pgbouncer=true"  # PgBouncer (runtime)
DIRECT_URL="postgresql://...@pooler.supabase.com:5432/postgres"                   # Direct (migrasi)

# Autentikasi
JWT_SECRET="ganti-dengan-secret-yang-kuat"

# Supabase Storage
SUPABASE_URL="https://YOUR_PROJECT_REF.supabase.co"
SUPABASE_SERVICE_ROLE_KEY="eyJ..."
SUPABASE_BUCKET="histopatologi"
STORAGE_PROVIDER="supabase"

# CORS (pisahkan beberapa origin dengan koma)
CORS_ORIGIN="http://localhost:5173"

# Kriptografi
AES_SECRET_KEY="<64 hex chars = 32 byte untuk AES-256>"   # enkripsi field NIK/BPJS
RSA_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"  # tanda tangan digital
RSA_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----"
```

> `AES_SECRET_KEY` wajib 64 karakter heksadesimal (32 byte). Pasangan `RSA_*` di-generate via `npx tsx scripts/generate-rsa-keys.ts`.

### Setelah server berjalan, dokumentasi interaktif tersedia di **`http://localhost:5001/api-docs`**.

---

## 🔐 Fitur Keamanan Informasi

### 1. Autentikasi — JWT

Stateless authentication menggunakan signed token.

- Token login berlaku **1 hari**, token reset password **15 menit**
- JWT Secret disimpan di environment variable, tidak hardcoded

**File:** [`src/utils/jwt.utils.ts`](03_Source_Code/backend/src/utils/jwt.utils.ts) | [`src/middlewares/authenticate.middleware.ts`](03_Source_Code/backend/src/middlewares/authenticate.middleware.ts)

---

### 2. Otorisasi — RBAC (Role-Based Access Control)

Kontrol akses berbasis peran (*Principle of Least Privilege*).

- Tiga peran: `OPERATOR_LAB`, `DOKTER_PATOLOGI`, `ADMIN_AI`
- Middleware `authenticate` verifikasi JWT; `authorize` batasi akses per-role
- Setiap endpoint mendefinisikan role yang diizinkan secara eksplisit

**File:** [`src/middlewares/authenticate.middleware.ts`](03_Source_Code/backend/src/middlewares/authenticate.middleware.ts)

---

### 3. Hashing Password — bcrypt

Password tidak pernah disimpan plaintext; menggunakan *adaptive hashing* tahan brute-force.

- bcrypt **salt rounds = 10**
- Password lama diverifikasi sebelum diganti; password baru tidak boleh sama dengan yang aktif

**File:** [`src/utils/hash.utils.ts`](03_Source_Code/backend/src/utils/hash.utils.ts) | [`src/services/auth.service.ts`](03_Source_Code/backend/src/services/auth.service.ts)

---

### 4. Kontrol Akses Berbasis Institusi

Isolasi data antar institusi (*data segregation*) untuk melindungi privasi pasien.

- `OPERATOR_LAB` hanya mengakses kasus dari institusi yang sama
- Pengecekan dilakukan di service layer via `assertSameInstitution()` → tolak akses (403) jika beda institusi

**File:** [`src/utils/access.utils.ts`](03_Source_Code/backend/src/utils/access.utils.ts)

---

### 5. Validasi Input — Zod Schema

Mencegah *injection attacks* dan data corruption melalui validasi ketat di semua endpoint.

- Setiap endpoint punya Zod schema eksplisit
- Middleware `validate()` dijalankan **sebelum** controller — data kotor tidak masuk ke business logic
- TypeScript `strict: true`, tidak ada `any` yang membawa data tidak aman

**File:** [`src/middlewares/validate.middleware.ts`](03_Source_Code/backend/src/middlewares/validate.middleware.ts) | [`src/validations/`](03_Source_Code/backend/src/validations/)

---

### 6. Manajemen Akun Terkontrol (Tanpa Registrasi Publik)

Menghilangkan attack surface registrasi publik (*Zero Trust*).

- Tidak ada endpoint `POST /register`; akun hanya dibuat admin langsung ke database
- First-login wajib ganti password (`is_first_login = true`)
- Akun dengan jejak klinis tidak dihapus, hanya dinonaktifkan (`is_active = false`)

**File:** [`src/services/auth.service.ts`](03_Source_Code/backend/src/services/auth.service.ts)

---

### 7. Soft Delete & Content Masking pada Komentar

Menjaga integritas rekam medis — data klinis tidak boleh dihapus permanen.

- Komentar tidak dihapus fisik dari database; flag `is_deleted = true`
- Konten di-*mask* menjadi `"pesan ini telah dihapus"` sebelum dikirim ke client
- Hanya penulis yang dapat menghapus komentarnya sendiri

**File:** [`src/services/comment.service.ts`](03_Source_Code/backend/src/services/comment.service.ts)

---

### 8. Presigned URL & Time-Limited Access untuk File Medis

Citra histopatologi tidak pernah diekspos publik; akses menggunakan *time-limited signed URL*.

- **Upload**: presigned URL berlaku **1 jam**
- **View**: signed URL berlaku **15 menit** — harus request ulang setelah expired

**File:** [`src/services/storage/supabase.storage.ts`](03_Source_Code/backend/src/services/storage/supabase.storage.ts)

---

### 9. Audit Trail — Append-Only Log

Non-repudiation — setiap aksi dapat dilacak dan tidak bisa disangkal.

- Model `AuditLog`: `user_id`, `action`, `entity_type`, `entity_id`, `payload`, `created_at`
- `writeAuditLog()` dipanggil di service pada aksi mutasi penting (`CREATE_PATIENT`, `GENERATE_REPORT`, `SIGN_REPORT`, dll.)
- Log **append-only** — tidak ada DELETE/UPDATE pada entri audit
- Penulisan **non-blocking**: kegagalan log tidak menggagalkan transaksi bisnis

**File:** [`src/utils/audit.utils.ts`](03_Source_Code/backend/src/utils/audit.utils.ts) | [`prisma/schema.prisma`](03_Source_Code/backend/prisma/schema.prisma)

---

### 10. Tanda Tangan Digital pada Laporan Klinis

Memastikan keaslian dan integritas laporan klinis (*non-repudiation* + *data integrity*).

- Saat finalisasi, snapshot laporan di-hash **SHA-256** lalu diikat dengan identitas penandatangan + waktu + ID laporan → segel tamper-evident
- Setelah ditandatangani, laporan **tidak dapat diubah atau ditandatangani ulang** (irreversible)
- Utilitas **RSA-2048 (RSA-SHA256)** tersedia di `signature.utils.ts` untuk verifikasi berbasis public key

**File:** [`src/services/report.service.ts`](03_Source_Code/backend/src/services/report.service.ts) | [`src/utils/signature.utils.ts`](03_Source_Code/backend/src/utils/signature.utils.ts)

---

### 11. Reset Password Stateless & Aman

Token reset tidak disimpan di database — mencegah serangan pencurian token dari DB.

- Reset token adalah JWT tersendiri (`purpose: "reset-password"`) berlaku **15 menit**
- Diverifikasi secara kriptografis — tidak perlu lookup DB
- Token login biasa ditolak jika digunakan sebagai reset token (validasi field `purpose`)

**File:** [`src/services/auth.service.ts`](03_Source_Code/backend/src/services/auth.service.ts) | [`src/types/auth.types.ts`](03_Source_Code/backend/src/types/auth.types.ts)

---

### 12. Enkripsi Field-Level — AES-256 (NIK & BPJS)

Data identitas sensitif tidak disimpan plaintext di database (*encryption at rest* level kolom).

- NIK dan `bpjs_number` dienkripsi **AES-256-ECB** sebelum disimpan, didekripsi otomatis saat dibaca
- Mode ECB (deterministik) dipilih agar constraint `@unique` PostgreSQL tetap berfungsi — plaintext sama → ciphertext sama
- Idempoten: nilai ber-prefix `aes256ecb:` tidak dienkripsi ganda
- Kunci dari `AES_SECRET_KEY` (32 byte / 64 hex), tidak hardcoded

> **Trade-off:** ECB tidak menyembunyikan pola pada data identik. Diterima karena field pendek (NIK 16 digit, BPJS 13 digit) demi mempertahankan unique constraint.

**File:** [`src/utils/crypto.utils.ts`](03_Source_Code/backend/src/utils/crypto.utils.ts) | [`src/services/patient.service.ts`](03_Source_Code/backend/src/services/patient.service.ts)

---

### 13. Rate Limiting — Mitigasi Brute-Force & Abuse

Membatasi laju permintaan untuk mencegah brute-force dan abuse API (*availability*).

- `generalLimiter`: **100 req / 15 menit** per IP untuk seluruh API
- `authLimiter`: **10 req / 15 menit** khusus `/api/auth` — lebih ketat untuk proteksi kredensial
- Respons HTTP **429** dengan format konsisten `{ status: "error" }`

**File:** [`src/middlewares/rate-limit.middleware.ts`](03_Source_Code/backend/src/middlewares/rate-limit.middleware.ts)

---

### Ringkasan Pemetaan ke Prinsip CIA Triad

| Prinsip                                 | Fitur yang Diimplementasikan                                                                               |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| **Confidentiality** (Kerahasiaan) | RBAC, Kontrol Akses Institusi, No Public Register, Signed URL 15 menit,**Enkripsi AES-256 NIK/BPJS** |
| **Integrity** (Integritas)        | Zod Validation, Soft Delete, Audit Log append-only, Tanda Tangan Digital SHA-256                           |
| **Availability** (Ketersediaan)   | Connection pooling (PgBouncer),**Rate Limiting (general & auth)**                                    |
| **Non-Repudiation**               | JWT stateless, Audit Trail (writeAuditLog), Tanda Tangan Digital Laporan                                   |
| **Authentication**                | JWT + bcrypt, First-login password change, Stateless reset token                                           |

---

## Alur Kerja Sistem

```
[OPERATOR_LAB] Daftar Pasien → Buat Kasus
        ↓
[OPERATOR_LAB] Upload citra (via Presigned URL ke Supabase)
        ↓
Sistem jalankan QC per citra → PASSED | FAILED
        ↓
[OPERATOR_LAB] Submit kasus → Case: PENDING_VALIDATION
        ↓
[DOKTER_PATOLOGI] Review antrian → Validasi AI Result per citra
        ↓
[DOKTER_PATOLOGI] Buat Consensus → Case: RESOLVED
        ↓
[DOKTER_PATOLOGI] Generate & tandatangani Laporan Digital
```

> **Status implementasi:** Fokus proyek adalah infrastruktur backend & keamanan informasi. Logika **QC citra** saat ini di-*mock* (otomatis `PASSED`) dan **inferensi AI** (`AiResult`/`AiFinding`) diisi via seeding — endpoint serta state machine sudah siap untuk integrasi model nyata di masa depan.

---

## API Endpoints

### Auth

| Method | Endpoint                         | Deskripsi                    |
| ------ | -------------------------------- | ---------------------------- |
| POST   | `/api/auth/login`              | Login → JWT token           |
| POST   | `/api/auth/update-credentials` | Ganti password (first login) |
| POST   | `/api/auth/forgot-password`    | Generate reset token         |
| POST   | `/api/auth/reset-password`     | Reset password via token     |

### Operator Lab

| Method    | Endpoint                                 | Akses            |
| --------- | ---------------------------------------- | ---------------- |
| GET/POST  | `/api/patients`                        | `OPERATOR_LAB` |
| GET/PATCH | `/api/patients/:id`                    | `OPERATOR_LAB` |
| GET/POST  | `/api/cases`                           | `OPERATOR_LAB` |
| POST      | `/api/cases/:id/images/presigned-urls` | `OPERATOR_LAB` |
| POST      | `/api/cases/:id/images/confirm`        | `OPERATOR_LAB` |
| POST      | `/api/cases/:id/submit`                | `OPERATOR_LAB` |
| DELETE    | `/api/images/:id`                      | `OPERATOR_LAB` |

### Dokter Patologi

| Method | Endpoint                                 | Akses                                 |
| ------ | ---------------------------------------- | ------------------------------------- |
| GET    | `/api/review/queue`                    | `DOKTER_PATOLOGI`                   |
| GET    | `/api/review/resolved`                 | `DOKTER_PATOLOGI`                   |
| GET    | `/api/review/cases/:caseId/images`     | `DOKTER_PATOLOGI`                   |
| GET    | `/api/review/cases/:caseId/images/:id` | `DOKTER_PATOLOGI`, `OPERATOR_LAB` |
| POST   | `/api/images/:id/validate`             | `DOKTER_PATOLOGI`                   |
| POST   | `/api/images/:id/comments`             | `DOKTER_PATOLOGI`, `OPERATOR_LAB` |
| POST   | `/api/cases/:id/consensus`             | `DOKTER_PATOLOGI`                   |

### Laporan Klinis

| Method | Endpoint                      | Akses               | Deskripsi                               |
| ------ | ----------------------------- | ------------------- | --------------------------------------- |
| POST   | `/api/reports`              | `DOKTER_PATOLOGI` | Generate laporan dari kasus`RESOLVED` |
| GET    | `/api/reports/:id`          | `DOKTER_PATOLOGI` | Ambil laporan + signed URL download     |
| PATCH  | `/api/reports/:id/finalize` | `DOKTER_PATOLOGI` | Tanda tangan digital (irreversible)     |

### Dokumentasi

| Method | Endpoint      | Deskripsi                                |
| ------ | ------------- | ---------------------------------------- |
| GET    | `/api-docs` | Swagger UI — dokumentasi API interaktif |

---

## Lisensi

Proyek ini dibuat untuk keperluan akademik — **Projek Akhir Keamanan Informasi**, Kelompok 7, Kelas K1, 2026.
