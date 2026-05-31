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

Sistem ini adalah capstone project untuk mata kuliah **Keamanan Informasi**. Sistem menangani data sensitif berupa:
- Data identitas pasien (NIK, nomor BPJS)
- Citra histopatologi medis
- Hasil analisis AI dan validasi dokter
- Laporan klinis berformat digital

Karena sensitivitas data, sistem dirancang dengan **keamanan sebagai prioritas utama** (*security by design*), bukan sebagai tambahan setelah sistem selesai dibangun.

### Aktor & Peran

| Role | Tugas |
|---|---|
| `OPERATOR_LAB` | Upload citra histopatologi, kelola data pasien & kasus |
| `DOKTER_PATOLOGI` | Review & validasi hasil skrining AI, beri komentar klinis |
| `ADMIN_AI` | Monitoring sistem AI |

---

## Anggota Kelompok

| Nama | NIM | Peran |
|---|---|---|
| Walid Nadirul Ahnaf | G6401231109 |
| Yasir | G6401231091 | |
| | | |

---

## Struktur Repositori

```
Projek Akhir KI/
├── 01_Proposal_&_Analisis/     # Dokumen proposal dan analisis kebutuhan
├── 02_Design_Documents/         # ERD, arsitektur sistem, diagram alur
│   └── ERD.png
├── 03_Source_Code/
│   ├── backend/                 # REST API (Node.js + TypeScript + Express)
│   │   ├── prisma/              # Schema database & migrasi
│   │   └── src/
│   │       ├── middlewares/     # authenticate, authorize, validate
│   │       ├── services/        # Business logic & keamanan domain
│   │       ├── utils/           # JWT, bcrypt, Supabase Storage
│   │       └── ...
│   ├── database/                # Script SQL tambahan
│   └── digital_signature/       # Implementasi tanda tangan digital
└── 04_Reports_&_Paper/          # Laporan akhir dan paper
```

---

## Tech Stack

| Layer | Teknologi | Versi |
|---|---|---|
| Runtime | Node.js (ES Modules) | LTS |
| Language | TypeScript (strict mode) | ^6.0 |
| Framework | Express | ^5.2 |
| ORM | Prisma | ^6.19 |
| Database | PostgreSQL via Supabase | — |
| Auth | JWT + bcrypt | — |
| Validation | Zod | ^4.3 |
| Testing | Vitest | ^4.1 |
| Storage | Supabase Storage | — |

---

## Cara Menjalankan

### Prasyarat
- Node.js LTS
- Akses ke database PostgreSQL (Supabase)

### Instalasi

```bash
cd 03_Source_Code/backend

# Install dependensi
npm install

# Setup environment variables
cp .env.example .env
# Edit .env dengan kredensial database dan JWT secret kamu

# Generate Prisma Client
npx prisma generate

# Jalankan migrasi database
npx prisma migrate dev

# (Opsional) Seed data dummy
npm run seed
```

### Menjalankan Server

```bash
# Development (hot-reload)
npm run dev

# Production
npm run build && npm start
```

### Menjalankan Test

```bash
# Jalankan semua test
npm test

# Test dengan coverage report
npm run test:coverage
```

### Environment Variables

```env
PORT=3000
DATABASE_URL="postgresql://...@pooler.supabase.com:6543/postgres?pgbouncer=true"
DIRECT_URL="postgresql://...@pooler.supabase.com:5432/postgres"
JWT_SECRET="..."
SUPABASE_URL="..."
SUPABASE_SERVICE_KEY="..."
```

---

## 🔐 Fitur Keamanan Informasi

> Bagian ini mendokumentasikan implementasi nyata dari prinsip-prinsip keamanan informasi yang diterapkan dalam sistem, lengkap dengan referensi ke source code.

### 1. Autentikasi — JWT (JSON Web Token)

**Konsep:** Stateless authentication menggunakan signed token.

**Implementasi:**
- Token di-generate saat login dengan masa berlaku **1 hari**
- Token di-verifikasi di setiap request yang memerlukan autentikasi
- Token reset password memiliki masa berlaku **15 menit** (lebih ketat)
- JWT Secret disimpan di environment variable, tidak hardcoded

```typescript
// src/utils/jwt.utils.ts
export const generateToken = <TPayload extends object>(
  payload: TPayload,
  expiresIn: SignOptions["expiresIn"] = "1d"
): string => {
  return jwt.sign(payload, getJwtSecret(), { expiresIn });
};
```

**File:** [`src/utils/jwt.utils.ts`](03_Source_Code/backend/src/utils/jwt.utils.ts) | [`src/middlewares/authenticate.middleware.ts`](03_Source_Code/backend/src/middlewares/authenticate.middleware.ts)

---

### 2. Otorisasi — Role-Based Access Control (RBAC)

**Konsep:** Kontrol akses berbasis peran pengguna (*Principle of Least Privilege*).

**Implementasi:**
- Tiga peran: `OPERATOR_LAB`, `DOKTER_PATOLOGI`, `ADMIN_AI`
- Middleware `authenticate` memverifikasi JWT, middleware `authorize` membatasi akses per-role
- Setiap endpoint secara eksplisit mendefinisikan role yang diizinkan

```typescript
// src/middlewares/authenticate.middleware.ts
export const authorize =
  (...roles: Role[]) =>
  (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user || !roles.includes(req.user.role as Role)) {
      res.status(403).json({ status: "error", message: "Anda tidak memiliki akses ke resource ini" });
      return;
    }
    next();
  };
```

**File:** [`src/middlewares/authenticate.middleware.ts`](03_Source_Code/backend/src/middlewares/authenticate.middleware.ts)

---

### 3. Hashing Password — bcrypt

**Konsep:** Password tidak pernah disimpan dalam bentuk plaintext. Menggunakan *adaptive hashing* agar tahan terhadap brute-force.

**Implementasi:**
- bcrypt dengan **salt rounds = 10** (cost factor adaptif)
- Password lama diverifikasi sebelum update password
- Password baru tidak boleh sama dengan password saat ini (cegah password reuse)

```typescript
// src/utils/hash.utils.ts
export const hashPassword = async (password: string): Promise<string> => {
  const salt = await bcrypt.genSalt(10);
  return bcrypt.hash(password, salt);
};
```

**File:** [`src/utils/hash.utils.ts`](03_Source_Code/backend/src/utils/hash.utils.ts) | [`src/services/auth.service.ts`](03_Source_Code/backend/src/services/auth.service.ts)

---

### 4. Kontrol Akses Berbasis Institusi

**Konsep:** Isolasi data antar institusi — *data segregation* untuk melindungi privasi pasien.

**Implementasi:**
- `OPERATOR_LAB` hanya dapat mengakses kasus dari institusi yang sama
- Pengecekan dilakukan di **service layer** via `assertSameInstitution()`
- Jika salah satu operator tidak memiliki institusi → akses **ditolak (403)**

```typescript
// src/utils/access.utils.ts
export const assertSameInstitution = async (userAId: string, userBId: string) => {
  // ...
  if (!userA?.institution || !userB?.institution) {
    throw new AppError("Akses ditolak: institusi tidak terdaftar", 403);
  }
  if (userA.institution !== userB.institution) {
    throw new AppError("Akses ditolak: resource milik institusi lain", 403);
  }
};
```

**File:** [`src/utils/access.utils.ts`](03_Source_Code/backend/src/utils/access.utils.ts)

---

### 5. Validasi Input — Zod Schema

**Konsep:** Mencegah *injection attacks* dan data corruption melalui validasi ketat di semua endpoint.

**Implementasi:**
- Setiap endpoint memiliki Zod schema yang terdefinisi eksplisit
- Middleware `validate()` dipanggil **sebelum** controller — data kotor tidak pernah masuk business logic
- TypeScript `strict: true` — tidak ada `any` type yang bisa membawa data tidak aman

```typescript
// src/middlewares/validate.middleware.ts
export const validate =
  <TSchema extends ZodType>(schema: TSchema, source: "body" | "query" = "body") =>
  (req: Request, res: Response, next: NextFunction): void => {
    try {
      const parsed = schema.parse(req[source]);
      req.body = parsed; // hanya data yang sudah tervalidasi yang masuk
      next();
    } catch (error: unknown) {
      if (error instanceof z.ZodError) {
        res.status(400).json({ status: "error", message: error.issues[0]?.message });
        return;
      }
    }
  };
```

**File:** [`src/middlewares/validate.middleware.ts`](03_Source_Code/backend/src/middlewares/validate.middleware.ts) | [`src/validations/`](03_Source_Code/backend/src/validations/)

---

### 6. Manajemen Akun Terkontrol (Tanpa Registrasi Publik)

**Konsep:** Mencegah akses tidak sah dengan menghilangkan attack surface registrasi publik (*Principle of Zero Trust*).

**Implementasi:**
- Tidak ada endpoint `POST /register`
- Akun hanya dibuat oleh admin langsung ke database
- First-login wajib ganti password (`is_first_login = true`)
- Pengguna dengan jejak klinis tidak dihapus, hanya dinonaktifkan (`is_active = false`)

```typescript
// src/services/auth.service.ts — login menolak akun nonaktif
if (!user || !user.is_active || !(await comparePassword(passwordInput, user.password_hash))) {
  throw new AppError("Email atau password tidak valid", 401);
}
```

**File:** [`src/services/auth.service.ts`](03_Source_Code/backend/src/services/auth.service.ts)

---

### 7. Soft Delete & Content Masking pada Komentar

**Konsep:** Menjaga integritas rekam medis — data klinis tidak boleh dihapus permanen (*data integrity for medical records*).

**Implementasi:**
- Komentar tidak dihapus secara fisik dari database
- Flag `is_deleted = true` + konten di-*mask* sebelum dikirim ke client
- Hanya penulis komentar yang dapat menghapus komentarnya sendiri

```typescript
// src/services/comment.service.ts
export const maskDeletedContent = (comment: { content: string; is_deleted: boolean }) =>
  comment.is_deleted ? { ...comment, content: "pesan ini telah dihapus" } : comment;
```

**File:** [`src/services/comment.service.ts`](03_Source_Code/backend/src/services/comment.service.ts)

---

### 8. Presigned URL & Time-Limited Access untuk File Medis

**Konsep:** Citra histopatologi tidak pernah diekspos secara publik. Akses menggunakan *time-limited signed URL*.

**Implementasi:**
- **Upload**: Presigned upload URL berlaku **1 jam** (`expiresInSeconds = 3600`)
- **View**: Signed view URL berlaku **15 menit** (`expiresInSeconds = 900`) — harus request ulang setelah expired
- File tidak bisa diakses langsung tanpa URL yang valid dan berlaku

```typescript
// src/utils/supabase-storage.utils.ts
export const createSignedViewUrl = async (
  filePath: string,
  expiresInSeconds = 900  // 15 menit
): Promise<string> => {
  const { data, error } = await supabase.storage
    .from(BUCKET)
    .createSignedUrl(filePath, expiresInSeconds);
  // ...
};
```

**File:** [`src/utils/supabase-storage.utils.ts`](03_Source_Code/backend/src/utils/supabase-storage.utils.ts)

---

### 9. Audit Trail — Append-Only Log

**Konsep:** Non-repudiation — setiap aksi dalam sistem dapat dilacak dan tidak bisa disangkal.

**Implementasi (Skema):**
- Model `AuditLog` di database: `user_id`, `action`, `entity_type`, `entity_id`, `payload`, `created_at`
- Log bersifat **append-only** — tidak ada operasi DELETE atau UPDATE pada entri audit
- Payload menggunakan tipe `JsonB` untuk fleksibilitas mencatat konteks aksi

```prisma
// prisma/schema.prisma
model AuditLog {
  id          String   @id @default(uuid())
  user_id     String
  action      String
  entity_type String
  entity_id   String
  payload     Json?    // JsonB — konteks lengkap aksi
  created_at  DateTime @default(now())
}
```

**File:** [`prisma/schema.prisma`](03_Source_Code/backend/prisma/schema.prisma)

---

### 10. Tanda Tangan Digital pada Laporan Klinis

**Konsep:** Memastikan keaslian dan integritas laporan klinis yang dihasilkan dokter — *non-repudiation* dan *data integrity*.

**Implementasi (Skema & Modul):**
- Model `Report` memiliki field `is_signed (Boolean)`, `digital_signature (String)`, dan `signed_at`
- Modul implementasi tersedia di [`03_Source_Code/digital_signature/`](03_Source_Code/digital_signature/)

```prisma
// prisma/schema.prisma
model Report {
  // ...
  is_signed          Boolean   @default(false)
  digital_signature  String?   // nilai tanda tangan digital
  signed_at          DateTime?
}
```

**File:** [`prisma/schema.prisma`](03_Source_Code/backend/prisma/schema.prisma) | [`03_Source_Code/digital_signature/`](03_Source_Code/digital_signature/)

---

### 11. Reset Password Stateless & Aman

**Konsep:** Token reset password tidak disimpan di database — mencegah serangan berbasis pencurian token dari DB.

**Implementasi:**
- Reset token adalah JWT tersendiri dengan `purpose: "reset-password"` dan masa berlaku **15 menit**
- Token diverifikasi secara kriptografis — tidak perlu lookup ke DB untuk validasi
- Sistem menolak token login biasa yang coba dipakai sebagai reset token (validasi field `purpose`)

```typescript
// src/services/auth.service.ts
const resetToken = generateToken(payload, "15m"); // expired dalam 15 menit

// Saat reset, verifikasi purpose untuk mencegah token hijacking:
if (decoded.purpose !== RESET_PASSWORD_PURPOSE) {
  throw new AppError("Token reset password tidak valid", 401);
}
```

**File:** [`src/services/auth.service.ts`](03_Source_Code/backend/src/services/auth.service.ts) | [`src/types/auth.types.ts`](03_Source_Code/backend/src/types/auth.types.ts)

---

### Ringkasan Pemetaan ke Prinsip CIA Triad

| Prinsip | Fitur yang Diimplementasikan |
|---|---|
| **Confidentiality** (Kerahasiaan) | RBAC, Kontrol Akses Institusi, No Public Register, Signed URL 15 menit |
| **Integrity** (Integritas) | Zod Validation, Soft Delete, Audit Log append-only, Tanda Tangan Digital |
| **Availability** (Ketersediaan) | Connection pooling (PgBouncer), Stale file cleanup, QC pipeline |
| **Non-Repudiation** | JWT stateless, Audit Trail, Tanda Tangan Digital Laporan |
| **Authentication** | JWT + bcrypt, First-login password change, Stateless reset token |

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

---

## API Endpoints

### Auth
| Method | Endpoint | Deskripsi |
|---|---|---|
| POST | `/api/auth/login` | Login → JWT token |
| POST | `/api/auth/update-credentials` | Ganti password (first login) |
| POST | `/api/auth/forgot-password` | Generate reset token |
| POST | `/api/auth/reset-password` | Reset password via token |

### Operator Lab
| Method | Endpoint | Akses |
|---|---|---|
| GET/POST | `/api/patients` | `OPERATOR_LAB` |
| GET/PATCH | `/api/patients/:id` | `OPERATOR_LAB` |
| GET/POST | `/api/cases` | `OPERATOR_LAB` |
| POST | `/api/cases/:id/images/presigned-urls` | `OPERATOR_LAB` |
| POST | `/api/cases/:id/images/confirm` | `OPERATOR_LAB` |
| POST | `/api/cases/:id/submit` | `OPERATOR_LAB` |
| DELETE | `/api/images/:id` | `OPERATOR_LAB` |

### Dokter Patologi
| Method | Endpoint | Akses |
|---|---|---|
| GET | `/api/review/queue` | `DOKTER_PATOLOGI` |
| GET | `/api/review/cases/:id/images` | `DOKTER_PATOLOGI` |
| POST | `/api/images/:id/validate` | `DOKTER_PATOLOGI` |
| POST | `/api/cases/:id/consensus` | `DOKTER_PATOLOGI` |

---

## Lisensi

Proyek ini dibuat untuk keperluan akademik — **Projek Akhir Keamanan Informasi**, Kelompok 7, Kelas K1, 2026.
