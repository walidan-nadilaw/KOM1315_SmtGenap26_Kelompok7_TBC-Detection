// =============================================================================
//  Laporan Teknis: Sistem Manajemen Lab & Skrining Awal Tuberkulosis (TBC)
//  Projek Akhir Keamanan Informasi · Kelompok 7 · Kelas K1 · 2026
//  Ditulis dalam Typst dengan format penulisan karya ilmiah.
//  Kompilasi:  typst compile Final_Technical_Report.typ
// =============================================================================

// ----------------------------------------------------------------------------
//  Pengaturan dokumen
// ----------------------------------------------------------------------------
#set document(
  title: "Laporan Teknis Sistem Manajemen Lab dan Skrining Awal Tuberkulosis (TBC)",
  author: ("Walid Nadirul Ahnaf", "Yasir", "Cokorda Satria"),
)

#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.5cm),
  numbering: "1",
  number-align: center,
)

#set text(
  font: ("Times New Roman", "Liberation Serif"),
  size: 11pt,
  lang: "id",
)

#set par(justify: true, leading: 0.75em, first-line-indent: 1.2em, spacing: 1.1em)

// Penomoran heading otomatis ala karya ilmiah (1, 1.1, 1.1.1)
#set heading(numbering: "1.1")
#show heading: set block(above: 1.4em, below: 0.8em)
#show heading.where(level: 1): set text(size: 15pt)
#show heading.where(level: 2): set text(size: 13pt)
#show heading.where(level: 3): set text(size: 11.5pt)

// Penomoran figur & tabel
#set figure(numbering: "1")
#show figure.caption: set text(size: 9.5pt, style: "italic")

// Gaya tautan
#show link: set text(fill: rgb("#0b5cad"))

// Gaya blok kode (dengan margin di sekeliling cuplikan)
#show raw.where(block: true): it => block(
  above: 1.3em,            // margin atas
  below: 1.3em,            // margin bawah
  pad(x: 1.2em,            // margin kiri-kanan (indentasi)
    block(
      fill: rgb("#f5f5f5"),
      inset: 10pt,         // padding di dalam kotak
      radius: 4pt,
      width: 100%,
      it,
    ),
  ),
)
#show raw: set text(font: ("Consolas", "DejaVu Sans Mono", "Courier New"), size: 9pt)

// ----------------------------------------------------------------------------
//  Fungsi bantu
// ----------------------------------------------------------------------------

// Placeholder figur untuk aset yang belum tersedia / berformat PDF
#let gambar-placeholder(judul, caption, sumber: none) = figure(
  block(
    fill: rgb("#fafafa"),
    stroke: (paint: rgb("#bbbbbb"), dash: "dashed"),
    inset: 16pt,
    radius: 4pt,
    width: 100%,
    align(center)[
      #text(fill: rgb("#888888"))[#emph(judul)]
      #if sumber != none [ \ #text(size: 8.5pt, fill: rgb("#999999"))[Sumber: #sumber] ]
    ],
  ),
  caption: caption,
)

// ----------------------------------------------------------------------------
//  Halaman judul
// ----------------------------------------------------------------------------
#align(center)[
  #v(2cm)
  #text(size: 20pt, weight: "bold")[
    Final Technical Report \
    Sistem Manajemen Lab & Skrining Awal \
    Tuberkulosis (TBC)
  ]

  #v(0.6cm)
  #text(size: 12pt)[
    Projek Akhir Keamanan Informasi 2026\
    Kelompok 7
  ]

  #v(1.2cm)
  #table(
    columns: (auto, auto),
    align: (left, left),
    inset: 8pt,
    stroke: none,
    [Walid Nadirul Ahnaf], [G6401231109],
    [Yasir], [G6401231091],
    [Cokorda Satria], [G6401231064],
  )
]

#pagebreak()

// ----------------------------------------------------------------------------
//  Daftar isi
// ----------------------------------------------------------------------------
#outline(title: [Daftar Isi], indent: auto, depth: 2)

#pagebreak()

// =============================================================================
= Ringkasan Sistem
// =============================================================================

== Latar Belakang

Tuberkulosis (TBC) masih menjadi beban kesehatan yang besar, dan Indonesia
termasuk negara dengan jumlah kasus tertinggi di dunia. Diagnosis histopatologi
TBC sangat bergantung pada keahlian dokter patologi dalam mengidentifikasi
struktur seluler khas pada citra jaringan. Digitalisasi proses ini ke dalam
sistem berbasis web mempercepat alur klinis, tetapi sekaligus memunculkan
kebutuhan perlindungan data medis yang sensitif (identitas pasien, citra
histopatologi, hasil analisis, serta keputusan klinis) agar kerahasiaan,
integritas, dan ketersediaannya tetap terjaga.

Sistem ini dibangun dengan pendekatan _human-in-the-loop_ (HITL): AI membantu
analisis awal, sementara keputusan akhir tetap berada pada dokter patologi.
Fokus utama proyek bukan pada performa model AI, melainkan pada arsitektur
keamanan backend yang melindungi seluruh alur kerja klinis digital.

== Tujuan & Ruang Lingkup

Tujuan dokumen ini adalah memaparkan secara teknis bagaimana 13 kontrol
keamanan diimplementasikan pada backend, ancaman apa yang dimitigasi tiap
kontrol, dan bukti bahwa kontrol tersebut berfungsi (dapat ditelusuri ke kode
dan ke hasil uji).

Ruang lingkup laporan dibatasi pada lapisan backend (REST API). Antarmuka
pengguna (React) tidak dibahas. Standar acuan keamanan: CIA Triad
(Confidentiality, Integrity, Availability) serta OWASP API Security Top 10
sebagai kerangka pemetaan ancaman.

== Status Implementasi

Agar laporan ini jujur dan tidak menyesatkan, dua bagian non-keamanan masih
berupa simulasi:

- Quality Control (QC) citra saat ini di-_mock_, sehingga seluruh citra otomatis
  berstatus `PASSED`. Endpoint dan _state machine_ sudah siap untuk integrasi
  QC nyata.
- Inferensi AI (`AiResult` / `AiFinding`) diisi melalui _database seeding_,
  bukan hasil model sungguhan. Skema, endpoint, dan alur validasi dokter sudah
  lengkap.

Seluruh kontrol keamanan yang dibahas di dokumen ini sudah berjalan nyata
pada kode.

// =============================================================================
= Arsitektur Sistem
// =============================================================================

== Arsitektur Berlapis (Layered Architecture)

Backend mengikuti pola _layered architecture_ dengan pemisahan tanggung jawab
yang tegas (_separation of concerns_) sehingga tiap mekanisme keamanan dapat
diaudit dan diuji secara independen:

```
Client (React)
   │  HTTPS  (Authorization: Bearer <JWT>)
   ▼
┌─────────────────────────────────────────────────────────────┐
│  ROUTES        definisi endpoint + rantai middleware          │
│  MIDDLEWARE    morgan → cors → rate-limit → authenticate →    │
│                authorize → validate(Zod)                      │
│  CONTROLLER    parse req → panggil service → kirim res         │
│  SERVICE       logika bisnis & keamanan domain (AppError)      │
│  PRISMA ORM    query parameterized → PostgreSQL                │
└─────────────────────────────────────────────────────────────┘
   │                                  │
   ▼                                  ▼
PostgreSQL (Supabase)         Supabase Object Storage
(data terstruktur,            (citra histopatologi & laporan,
 kolom sensitif terenkripsi)   akses via signed URL berumur pendek)
```

Prinsip kunci dari desain ini adalah seluruh logika domain dan keamanan domain
berada di service layer. Controller tidak boleh memuat logika bisnis; ia hanya
menjembatani HTTP dengan service. Hal ini membuat kontrol keamanan (mis.
`assertSameInstitution()`) terpusat dan tidak tersebar/duplikatif.

#figure(
  image("image/Architecture Diagram.png", width: 55%),
  caption: [Diagram arsitektur berlapis sistem.],
)

Urutan pemasangan middleware global terlihat pada
#link("../../03_Source_Code/backend/src/index.ts")[`src/index.ts`]:

```ts
app.use(morgan('dev'));           // logging HTTP (akuntabilitas jaringan)
app.use(express.json());
app.use(cors(corsOptions));       // batasi origin lewat CORS_ORIGIN
app.use(generalLimiter);          // rate limit global: 100 req / 15 menit / IP
app.use('/api/auth', authLimiter, authRoutes);  // rate limit ketat: 10 req / 15 menit
```

```
Client Request  (Authorization: Bearer <JWT>)
      │
      ▼
morgan('dev') ──────────────── log HTTP: metode, rute, status, waktu
      │
generalLimiter ─────────────── tolak 429 jika > 100 req / 15 menit / IP
      │
authLimiter  (/api/auth) ───── tolak 429 jika > 10 req / 15 menit / IP
      │
authenticate ───────────────── tolak 401 jika token tidak ada / tidak valid
      │
authorize(...roles) ────────── tolak 403 jika role tidak diizinkan
      │
validate(ZodSchema) ────────── tolak 400 jika payload tidak valid
      │
      ▼
Controller → Service → Prisma ORM → PostgreSQL
```

== Trust Boundary

Terdapat empat zona kepercayaan yang berbeda; setiap perpindahan antar-zona
adalah titik penegakan keamanan:

#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    inset: 7pt,
    stroke: 0.5pt + rgb("#cccccc"),
    table.header([*Zona*], [*Kepercayaan*], [*Kontrol di perbatasan*]),
    [Client (browser)], [Tidak tepercaya], [CORS, JWT wajib, validasi Zod],
    [Backend API], [Tepercaya (inti)], [RBAC, isolasi institusi, audit log],
    [Object Storage], [Semi-tepercaya], [Akses hanya via _presigned/signed URL_ berumur pendek],
    [PostgreSQL], [Tepercaya (data at-rest)], [Enkripsi field-level NIK/BPJS, query terparameterisasi (Prisma)],
  ),
  caption: [Empat zona kepercayaan (trust boundary) dan kontrolnya.],
)

== Tech Stack

#figure(
  table(
    columns: (auto, 1fr, auto),
    align: (left, left, left),
    inset: 7pt,
    stroke: 0.5pt + rgb("#cccccc"),
    table.header([*Layer*], [*Teknologi*], [*Versi*]),
    [Runtime], [Node.js (ES Modules)], [LTS],
    [Bahasa], [TypeScript (strict mode)], [^6.0],
    [Framework], [Express], [^5.2],
    [ORM], [Prisma], [^6.19],
    [Database], [PostgreSQL via Supabase], [–],
    [Autentikasi], [JWT (`jsonwebtoken`) + bcrypt], [–],
    [Validasi], [Zod], [^4.3],
    [Rate Limiting], [express-rate-limit], [^8.5],
    [Kriptografi], [Node `crypto` (AES-256, RSA-2048, SHA-256)], [built-in],
    [Logging], [morgan], [–],
    [Storage], [Supabase Object Storage], [–],
    [Dokumentasi API], [Swagger (swagger-jsdoc + swagger-ui-express)], [–],
    [Testing], [Vitest], [^4.1],
  ),
  caption: [Tumpukan teknologi (tech stack) backend.],
)

// =============================================================================
= Model Data & Keamanan Data
// =============================================================================

Sumber kebenaran skema:
#link("../../03_Source_Code/backend/prisma/schema.prisma")[`prisma/schema.prisma`].
Tabel di bawah menyoroti properti keamanan tiap entitas, bukan seluruh field.

#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    inset: 7pt,
    stroke: 0.5pt + rgb("#cccccc"),
    table.header([*Entitas*], [*Peran*], [*Properti keamanan*]),
    [`User`], [Akun & peran],
      [`password_hash` (bcrypt), `role` (RBAC), `institution` (isolasi), `is_first_login`, `is_active` (nonaktif, bukan hapus)],
    [`Patient`], [Identitas pasien],
      [`no_induk` dan `bpjs_number` disimpan terenkripsi AES-256 (keduanya `@unique`)],
    [`Case`], [Kasus klinis],
      [`created_by` → dasar pengecekan `assertSameInstitution()`],
    [`Image`], [Citra histopatologi],
      [`file_path` di Object Storage; akses hanya via signed URL],
    [`Comment`], [Diskusi antar-dokter],
      [`is_deleted` (soft delete); konten di-_mask_ sebelum dikirim],
    [`Report`], [Laporan klinis],
      [`is_signed`, `digital_signature` (SHA-256, _tamper-evident_), bersifat _irreversible_ setelah ditandatangani],
    [`AuditLog`], [Jejak audit],
      [_append-only_: `user_id`, `action`, `entity_type`, `entity_id`, `payload`, `created_at`],
  ),
  caption: [Properti keamanan tiap entitas data.],
)

#figure(
  image("../../02_Design_Documents/ERD.png", width: 55%),
  caption: [Entity Relationship Diagram sistem (sumber: `02_Design_Documents/ERD.png`).],
)

Catatan integritas data: entitas dengan jejak klinis tidak pernah dihapus
permanen. `User` dinonaktifkan via `is_active = false`, `Comment` dihapus
secara _soft_, dan `AuditLog` bersifat _append-only_. Ini menjaga keaslian
rekam medis dan mendukung _non-repudiation_.

// =============================================================================
= Kontrol Keamanan
// =============================================================================

Tiga belas kontrol berikut adalah inti laporan. Setiap kontrol disajikan dengan
format seragam: (a) ancaman yang dimitigasi, (b) mekanisme, (c) implementasi
(file dan cuplikan), (d) trade-off atau catatan, dan (e) pilar CIA. Seluruh
cuplikan kode diambil langsung dari sumbernya.

== Autentikasi: JWT (HS256)

- *(a) Ancaman*: _Spoofing_ identitas, pembajakan sesi. (OWASP API2:2023, Broken Authentication)
- *(b) Mekanisme*: autentikasi _stateless_ berbasis _signed token_. Token login
  berlaku 1 hari; setiap request ke rute tertutup wajib membawa
  `Authorization: Bearer <token>`. JWT secret disimpan di environment variable,
  tidak _hardcoded_.
- *(c) Implementasi*:
  #link("../../03_Source_Code/backend/src/utils/jwt.utils.ts")[`src/utils/jwt.utils.ts`],
  #link("../../03_Source_Code/backend/src/middlewares/authenticate.middleware.ts")[`src/middlewares/authenticate.middleware.ts`]:

```ts
export const generateToken = <TPayload extends object>(
  payload: TPayload,
  expiresIn: SignOptions["expiresIn"] = "1d"
): string => jwt.sign(payload, getJwtSecret(), { expiresIn });
```

```ts
export const authenticate = (req, res, next): void => {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    res.status(401).json({ status: "error", message: "Token autentikasi tidak ditemukan" });
    return;
  }
  const token = authHeader.split(" ")[1]!;
  try {
    req.user = verifyToken<LoginTokenPayload>(token);
    next();
  } catch {
    res.status(401).json({ status: "error", message: "Token tidak valid atau kedaluwarsa" });
  }
};
```

- *(d) Trade-off*: JWT _stateless_ tidak punya mekanisme _revocation_ sebelum
  kedaluwarsa (lihat §8). Algoritma HS256 dipilih (default `jsonwebtoken`)
  karena kunci simetris cukup untuk sistem single-issuer.
- *(e) Pilar*: Authentication, Confidentiality.

#figure(
  image("image/token bearer.png", width: 100%),
  caption: [Token JWT yang dibawa pada header `Authorization: Bearer`.],
)

== Otorisasi: RBAC (Role-Based Access Control)

- *(a) Ancaman*: _Elevation of Privilege_, yaitu pengguna peran rendah mengakses
  operasi peran lain. (OWASP API5:2023, Broken Function Level Authorization)
- *(b) Mekanisme*: _Principle of Least Privilege_. Tiga peran: `OPERATOR_LAB`,
  `DOKTER_PATOLOGI`, `ADMIN_AI`. Middleware `authenticate` memverifikasi JWT,
  lalu `authorize(...roles)` membatasi akses per peran secara eksplisit di tiap rute.
- *(c) Implementasi*:
  #link("../../03_Source_Code/backend/src/middlewares/authenticate.middleware.ts")[`src/middlewares/authenticate.middleware.ts`]:

```ts
export const authorize =
  (...roles: Role[]) =>
  (req, res, next): void => {
    if (!req.user || !roles.includes(req.user.role as Role)) {
      res.status(403).json({ status: "error", message: "Anda tidak memiliki akses ke resource ini" });
      return;
    }
    next();
  };
```

- *(d) Trade-off*: otorisasi tingkat fungsi (per endpoint) dilengkapi otorisasi
  tingkat objek via isolasi institusi (§4.4) agar BOLA tertutup.
- *(e) Pilar*: Confidentiality, Integrity.

== Hashing Password: bcrypt

- *(a) Ancaman*: _Information Disclosure_ kredensial jika DB bocor; brute-force. (OWASP API2:2023)
- *(b) Mekanisme*: password tidak pernah disimpan _plaintext_. _Adaptive
  hashing_ bcrypt dengan salt rounds = 10 memperlambat brute-force secara sengaja.
- *(c) Implementasi*:
  #link("../../03_Source_Code/backend/src/utils/hash.utils.ts")[`src/utils/hash.utils.ts`]:

```ts
export const hashPassword = async (password: string): Promise<string> => {
  const salt = await bcrypt.genSalt(10);
  return bcrypt.hash(password, salt);
};
```

Saat ganti password, sistem memverifikasi password lama dan menolak password
baru yang sama dengan yang aktif (lihat
#link("../../03_Source_Code/backend/src/services/auth.service.ts")[`auth.service.ts`]).

- *(d) Trade-off*: _cost factor_ 10 menambah latensi login (\~72 ms, lihat §6.3).
  Ini adalah _trade-off_ keamanan yang disengaja, bukan degradasi.
- *(e) Pilar*: Confidentiality, Authentication.

#figure(
  image("image/Password bcrypt.png", width: 100%),
  caption: [Kolom `password_hash` di basis data dalam bentuk hash bcrypt, bukan plaintext.],
)

== Kontrol Akses Berbasis Institusi (Multi-tenant Isolation)

- *(a) Ancaman*: akses silang data antar fasilitas kesehatan; _Broken Object
  Level Authorization_. (OWASP API1:2023, BOLA)
- *(b) Mekanisme*: _data segregation_. Pengguna hanya dapat mengakses
  kasus/citra/laporan milik institusi yang sama. Pengecekan di service layer
  via `assertSameInstitution()`, yang menolak 403 bila institusi berbeda atau
  salah satu `institution` bernilai `null`.
- *(c) Implementasi*:
  #link("../../03_Source_Code/backend/src/utils/access.utils.ts")[`src/utils/access.utils.ts`]:

```ts
export const assertSameInstitution = async (userAId: string, userBId: string) => {
  const [userA, userB] = await Promise.all([
    prisma.user.findUnique({ where: { id: userAId }, select: { institution: true } }),
    prisma.user.findUnique({ where: { id: userBId }, select: { institution: true } }),
  ]);
  if (!userA?.institution || !userB?.institution) {
    throw new AppError("Akses ditolak: institusi tidak terdaftar", 403);
  }
  if (userA.institution !== userB.institution) {
    throw new AppError("Akses ditolak: resource milik institusi lain", 403);
  }
};
```

Helper ini dipanggil di service yang mengakses data milik institusi, mis.
#link("../../03_Source_Code/backend/src/services/report.service.ts")[`report.service.ts`] dan
#link("../../03_Source_Code/backend/src/services/comment.service.ts")[`comment.service.ts`].

- *(d) Trade-off*: pengecekan berbasis logika bisnis (bukan _row-level security_
  DB), sehingga lebih fleksibel dan dapat diuji, namun harus konsisten dipanggil
  di setiap operasi mutasi.
- *(e) Pilar*: Confidentiality, Integrity.


== Validasi Input: Zod Schema

- *(a) Ancaman*: _Tampering_ / _injection_ dan korupsi data dari payload anomali.
- *(b) Mekanisme*: setiap endpoint memiliki Zod schema eksplisit. Middleware
  `validate()` dijalankan sebelum controller, sehingga data kotor ditolak (400)
  sebelum menyentuh logika bisnis. TypeScript `strict: true` mencegah `any`
  membawa data tak aman.
- *(c) Implementasi*:
  #link("../../03_Source_Code/backend/src/middlewares/validate.middleware.ts")[`src/middlewares/validate.middleware.ts`]:

```ts
export const validate =
  <TSchema extends ZodType>(schema: TSchema, source: "body" | "query" = "body") =>
  (req, res, next): void => {
    try {
      const parsed = schema.parse(req[source]);
      if (source === "body") req.body = parsed;
      else Object.defineProperty(req, "query", { value: parsed, writable: true, configurable: true });
      next();
    } catch (error: unknown) {
      if (error instanceof z.ZodError) {
        res.status(400).json({ status: "error", message: error.issues[0]?.message ?? "Payload tidak valid" });
        return;
      }
      res.status(500).json({ status: "error", message: "Terjadi kesalahan internal saat validasi request" });
    }
  };
```

Catatan: penggunaan Prisma ORM dengan query terparameterisasi sudah memitigasi
SQL injection pada lapisan akses data; validasi Zod menambah pertahanan di
gerbang masuk.

- *(d) Trade-off*: hanya pesan _issue_ pertama yang dikembalikan (UX ringkas),
  bukan seluruh daftar error.
- *(e) Pilar*: Integrity.

== Manajemen Akun Terkontrol (Tanpa Registrasi Publik + First-Login)

- *(a) Ancaman*: penyalahgunaan pendaftaran publik; _credential stuffing_ pada
  kredensial bawaan. (OWASP API2:2023)
- *(b) Mekanisme*: pendekatan _zero-trust_ terhadap pembuatan akun. Tidak ada
  endpoint `POST /register`; akun dibuat admin langsung ke DB. Login pertama
  wajib ganti password (`is_first_login = true`). Akun berjejak klinis
  dinonaktifkan, tidak dihapus.
- *(c) Implementasi*:
  #link("../../03_Source_Code/backend/src/services/auth.service.ts")[`src/services/auth.service.ts`]:

```ts
export const updateCredential = async (email, currentPassword, newPassword, confirmPassword) => {
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) throw new AppError("Email atau password tidak valid", 401);
  if (!user.is_first_login) throw new AppError("Akun ini tidak memerlukan update credential awal", 400);
  // ... verifikasi password lama, cek konfirmasi, larang password sama, lalu hash & simpan
};
```

- *(d) Trade-off*: penyediaan akun bersifat manual/administratif, menukar
  kemudahan onboarding demi memperkecil _attack surface_.
- *(e) Pilar*: Authentication, Confidentiality.

#figure(
  image("image/First-login ganti password.png", width: 100%),
  caption: [Pengguna diwajibkan mengganti password bawaan saat login pertama.],
)

== Soft Delete & Content Masking pada Komentar

- *(a) Ancaman*: hilangnya jejak diskusi klinis; _Repudiation_ / _Tampering_ rekam medis.
- *(b) Mekanisme*: komentar tidak dihapus fisik, melainkan ditandai
  `is_deleted = true`, dan kontennya di-_mask_ menjadi teks netral sebelum
  dikirim ke client. Hanya penulis yang dapat menghapus komentarnya sendiri.
- *(c) Implementasi*:
  #link("../../03_Source_Code/backend/src/services/comment.service.ts")[`src/services/comment.service.ts`]:

```ts
export const DELETED_CONTENT = "pesan ini telah dihapus";

export const maskDeletedContent = (comment: { content: string; is_deleted: boolean }) =>
  comment.is_deleted ? { ...comment, content: DELETED_CONTENT } : comment;

export const deleteComment = async (commentId: string, requesterId: string) => {
  const comment = await prisma.comment.findUnique({ where: { id: commentId } });
  if (!comment) throw new AppError("Komentar tidak ditemukan", 404);
  if (comment.is_deleted) throw new AppError("Komentar sudah dihapus", 409);
  if (comment.commentator_id !== requesterId)
    throw new AppError("Akses ditolak: hanya penulis komentar yang dapat menghapusnya", 403);
  return prisma.comment.update({ where: { id: commentId }, data: { is_deleted: true } });
};
```

- *(d) Trade-off*: data terhapus tetap menempati basis data; diterima demi
  integritas riwayat.
- *(e) Pilar*: Integrity, Non-Repudiation.

== Presigned URL & Akses File Berbatas Waktu

- *(a) Ancaman*: _Information Disclosure_ citra/laporan medis melalui pembagian
  tautan publik. (OWASP API1:2023)
- *(b) Mekanisme*: berkas medis tidak pernah diekspos publik. Akses memakai
  _time-limited signed URL_: upload berlaku 1 jam, sedangkan view/download
  berlaku 15 menit (900 detik) dan harus diminta ulang setelah kedaluwarsa.
- *(c) Implementasi*:
  #link("../../03_Source_Code/backend/src/services/storage/supabase.storage.ts")[`src/services/storage/supabase.storage.ts`]:

```ts
async createPresignedUploadUrl(filePath: string, expiresInSeconds = 3600): Promise<string> { /* ... */ }

async createSignedViewUrl(filePath: string, expiresInSeconds = 900): Promise<string> {
  const { data, error } = await supabase.storage.from(BUCKET).createSignedUrl(filePath, expiresInSeconds);
  if (error || !data?.signedUrl) throw new AppError("Gagal membuat URL view", 500);
  return data.signedUrl;
}
```

- *(d) Trade-off*: durasi pendek meningkatkan keamanan namun menuntut client
  me-_refresh_ URL.
- *(e) Pilar*: Confidentiality.

== Audit Trail: Append-Only Log

- *(a) Ancaman*: _Repudiation_, yaitu pelaku menyangkal tindakannya.
- *(b) Mekanisme*: setiap aksi mutasi penting dicatat ke `AuditLog`. Log bersifat
  _append-only_ (tidak ada UPDATE/DELETE). Penulisan bersifat non-blocking:
  kegagalan log tidak menggagalkan transaksi bisnis.
- *(c) Implementasi*:
  #link("../../03_Source_Code/backend/src/utils/audit.utils.ts")[`src/utils/audit.utils.ts`]:

```ts
export const writeAuditLog = async (userId, action, entityType, entityId, payload?) => {
  try {
    await prisma.auditLog.create({
      data: { user_id: userId, action, entity_type: entityType, entity_id: entityId,
        ...(payload !== undefined && { payload: payload as Prisma.InputJsonValue }) },
    });
  } catch (err) {
    console.error("[AuditLog] Gagal menulis audit log:", err); // non-blocking
  }
};
```

Dipanggil pada aksi mutasi seperti `CREATE_PATIENT`, `UPDATE_PATIENT`,
`GENERATE_REPORT`, `SIGN_REPORT`. Selain audit tingkat aplikasi, middleware
morgan mencatat seluruh request HTTP (rute, metode, status, waktu) untuk
deteksi anomali & forensik.

- *(d) Trade-off*: desain non-blocking memilih _availability_ di atas jaminan
  tulis log; risiko kehilangan sebagian entri saat DB bermasalah, dengan
  kompensasi log error di konsol.
- *(e) Pilar*: Non-Repudiation, Integrity.

#figure(
  image("image/Audit Log.png", width: 100%),
  caption: [Contoh baris `AuditLog` (append-only) di basis data.],
)

== Tanda Tangan Digital pada Laporan Klinis

- *(a) Ancaman*: _Tampering_ isi laporan; _Repudiation_ atas laporan yang diterbitkan.
- *(b) Mekanisme*: saat finalisasi, _snapshot_ laporan di-hash SHA-256, lalu
  hash tersebut diikat dengan ID laporan, identitas penandatangan, dan waktu
  menjadi segel _tamper-evident_. Setelah ditandatangani, laporan tidak dapat
  diubah atau ditandatangani ulang (_irreversible_).
- *(c) Implementasi*:
  #link("../../03_Source_Code/backend/src/services/report.service.ts")[`src/services/report.service.ts`]:

```ts
const snapshotBytes = await storage.downloadFile(report.file_path);
const contentHash = crypto.createHash("sha256").update(snapshotBytes).digest("hex");

// Ikat hash konten + ID laporan + identitas penandatangan + waktu
const signatureInput = [contentHash, report.id, patologId, signedAt.toISOString()].join("|");
const digitalSignature = crypto.createHash("sha256").update(signatureInput).digest("hex");
```

- *(d) Trade-off*: skema saat ini berbasis hash SHA-256 (simetris), sehingga
  mampu mendeteksi perubahan, tetapi belum mendukung verifikasi independen pihak
  ketiga. Utilitas asimetris RSA-2048 (RSA-SHA256) sudah disiapkan di
  #link("../../03_Source_Code/backend/src/utils/signature.utils.ts")[`src/utils/signature.utils.ts`]
  sebagai rencana penyempurnaan (lihat §8).
- *(e) Pilar*: Integrity, Non-Repudiation.

== Reset Password Stateless & Aman

- *(a) Ancaman*: pencurian token reset dari DB; penyalahgunaan token login
  sebagai token reset. (OWASP API2:2023)
- *(b) Mekanisme*: token reset adalah JWT tersendiri (`purpose: "reset_password"`)
  berlaku 15 menit, diverifikasi secara kriptografis tanpa _lookup_ DB. Token
  login biasa ditolak bila dipakai untuk reset (validasi field `purpose`).
- *(c) Implementasi*:
  #link("../../03_Source_Code/backend/src/services/auth.service.ts")[`src/services/auth.service.ts`],
  #link("../../03_Source_Code/backend/src/types/auth.types.ts")[`src/types/auth.types.ts`]:

```ts
export const resetPassword = async (token: string, newPassword: string) => {
  const decoded = verifyToken<PasswordResetTokenPayload>(token);
  if (decoded.purpose !== RESET_PASSWORD_PURPOSE)
    throw new AppError("Token reset password tidak valid", 401);
  // ... cek user, larang password sama, hash & simpan
};
```

- *(d) Trade-off*: karena _stateless_, token tidak bisa dicabut sebelum 15 menit
  berakhir; jendela waktu sengaja dibuat pendek untuk membatasi risiko.
- *(e) Pilar*: Authentication, Confidentiality.

== Enkripsi Field-Level: AES-256 (NIK & BPJS)

- *(a) Ancaman*: _Information Disclosure_ identitas pasien bila DB bocor
  (_encryption at rest_ tingkat kolom).
- *(b) Mekanisme*: `no_induk` (NIK) dan `bpjs_number` dienkripsi AES-256-ECB
  sebelum disimpan dan didekripsi otomatis saat dibaca. Mode ECB (deterministik)
  dipilih agar plaintext sama menghasilkan ciphertext sama, sehingga constraint
  `@unique` PostgreSQL tetap berfungsi. Idempoten: nilai ber-prefix
  `aes256ecb:` tidak dienkripsi ganda.
- *(c) Implementasi*:
  #link("../../03_Source_Code/backend/src/utils/crypto.utils.ts")[`src/utils/crypto.utils.ts`],
  dipakai di
  #link("../../03_Source_Code/backend/src/services/patient.service.ts")[`src/services/patient.service.ts`]:

```ts
export const encryptField = (plaintext: string): string => {
  if (plaintext.startsWith(PREFIX)) return plaintext;       // idempoten
  const key = getAesKey();                                  // 32 byte dari AES_SECRET_KEY (64 hex)
  const cipher = crypto.createCipheriv("aes-256-ecb", key, null);
  const encrypted = Buffer.concat([cipher.update(plaintext, "utf-8"), cipher.final()]);
  return `${PREFIX}${encrypted.toString("hex")}`;
};
```

Trade-off eksplisit: ECB tidak menyembunyikan pola pada data identik.
Diterima karena field identifikasi pendek (NIK 16 digit, BPJS 13 digit) dan
demi mempertahankan _unique constraint_. Kunci berasal dari `AES_SECRET_KEY`,
tidak _hardcoded_.

- *(e) Pilar*: Confidentiality.

#figure(
  image("image/NIK-BPJS terenkripsi.png", width: 100%),
  caption: [Kolom `no_induk` dan `bpjs_number` tersimpan sebagai ciphertext AES-256.],
)

== Rate Limiting: Mitigasi Brute-Force & Abuse

- *(a) Ancaman*: _Denial of Service_, brute-force, abuse API. (OWASP API4:2023,
  Unrestricted Resource Consumption)
- *(b) Mekanisme*: dua pembatas laju, yaitu `generalLimiter` (100 req / 15 menit
  per IP untuk seluruh API) dan `authLimiter` (10 req / 15 menit khusus
  `/api/auth`, lebih ketat untuk proteksi kredensial). Pelanggaran dibalas
  HTTP 429 dengan format konsisten.
- *(c) Implementasi*:
  #link("../../03_Source_Code/backend/src/middlewares/rate-limit.middleware.ts")[`src/middlewares/rate-limit.middleware.ts`]:

```ts
export const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, max: 100, standardHeaders: true, legacyHeaders: false,
  message: "Terlalu banyak permintaan, coba lagi dalam 15 menit", handler: rateLimitResponse,
});

export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, max: 10, standardHeaders: true, legacyHeaders: false,
  message: "Terlalu banyak percobaan login, coba lagi dalam 15 menit", handler: rateLimitResponse,
});
```

- *(d) Trade-off*: pembatasan per-IP dapat memberi efek ke pengguna di belakang
  NAT bersama; ambang dipilih cukup longgar untuk pemakaian normal.
- *(e) Pilar*: Availability.

== Ringkasan Pemetaan CIA Triad

#figure(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: 7pt,
    stroke: 0.5pt + rgb("#cccccc"),
    table.header([*Pilar*], [*Kontrol yang berkontribusi*]),
    [*Confidentiality*],
      [JWT (§4.1), RBAC (§4.2), bcrypt (§4.3), Isolasi institusi (§4.4), No public register (§4.6), Signed URL (§4.8), Reset stateless (§4.11), AES-256 NIK/BPJS (§4.12)],
    [*Integrity*],
      [Validasi Zod (§4.5), Soft delete (§4.7), Audit log append-only (§4.9), Tanda tangan digital (§4.10)],
    [*Availability*],
      [Rate limiting (§4.13), audit log non-blocking (§4.9)],
    [*Non-Repudiation*],
      [Audit trail (§4.9), Tanda tangan digital (§4.10), Soft delete (§4.7)],
    [*Authentication*],
      [JWT + bcrypt (§4.1, §4.3), First-login (§4.6), Reset token stateless (§4.11)],
  ),
  caption: [Pemetaan kontrol keamanan ke pilar CIA Triad.],
)

// =============================================================================
= API Reference
// =============================================================================

== Matriks Endpoint × Peran

*Auth* (rute publik, dilindungi `authLimiter`):

#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    inset: 7pt,
    stroke: 0.5pt + rgb("#cccccc"),
    table.header([*Method*], [*Endpoint*], [*Deskripsi*]),
    [POST], [`/api/auth/login`], [Login → JWT token],
    [POST], [`/api/auth/update-credentials`], [Ganti password (first login)],
    [POST], [`/api/auth/forgot-password`], [Generate reset token],
    [POST], [`/api/auth/reset-password`], [Reset password via token],
  ),
  caption: [Endpoint autentikasi.],
)

*Operator Lab* (`OPERATOR_LAB`):

#figure(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    inset: 7pt,
    stroke: 0.5pt + rgb("#cccccc"),
    table.header([*Method*], [*Endpoint*]),
    [GET/POST], [`/api/patients`],
    [GET/PATCH], [`/api/patients/:id`],
    [GET/POST], [`/api/cases`],
    [POST], [`/api/cases/:id/images/presigned-urls`],
    [POST], [`/api/cases/:id/images/confirm`],
    [POST], [`/api/cases/:id/submit`],
    [DELETE], [`/api/images/:id`],
  ),
  caption: [Endpoint Operator Lab.],
)

*Dokter Patologi* (`DOKTER_PATOLOGI`; sebagian berbagi dengan `OPERATOR_LAB`):

#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    inset: 7pt,
    stroke: 0.5pt + rgb("#cccccc"),
    table.header([*Method*], [*Endpoint*], [*Akses*]),
    [GET], [`/api/review/queue`], [`DOKTER_PATOLOGI`],
    [GET], [`/api/review/resolved`], [`DOKTER_PATOLOGI`],
    [GET], [`/api/review/cases/:caseId/images`], [`DOKTER_PATOLOGI`],
    [GET], [`/api/review/cases/:caseId/images/:id`], [`DOKTER_PATOLOGI`, `OPERATOR_LAB`],
    [POST], [`/api/images/:id/validate`], [`DOKTER_PATOLOGI`],
    [POST], [`/api/images/:id/comments`], [`DOKTER_PATOLOGI`, `OPERATOR_LAB`],
    [POST], [`/api/cases/:id/consensus`], [`DOKTER_PATOLOGI`],
  ),
  caption: [Endpoint Dokter Patologi.],
)

*Laporan Klinis* (`DOKTER_PATOLOGI`):

#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    inset: 7pt,
    stroke: 0.5pt + rgb("#cccccc"),
    table.header([*Method*], [*Endpoint*], [*Deskripsi*]),
    [POST], [`/api/reports`], [Generate laporan dari kasus `RESOLVED`],
    [GET], [`/api/reports/:id`], [Ambil laporan + signed URL download (15 menit)],
    [PATCH], [`/api/reports/:id/finalize`], [Tanda tangan digital (irreversible)],
  ),
  caption: [Endpoint Laporan Klinis.],
)

*Dokumentasi*: endpoint `GET /api-docs` menyajikan Swagger UI interaktif.

== Format Response Standar

```jsonc
// Sukses
{ "status": "success", "message": "...", "data": { } }
// Sukses + pagination
{ "status": "success", "message": "...", "data": [ ], "meta": { "total": 0, "page": 1, "limit": 10 } }
// Error (via AppError → error-handler middleware)
{ "status": "error", "message": "Pesan error yang jelas" }
```

// =============================================================================
= Pengujian & Evaluasi Keamanan
// =============================================================================

== Unit Testing

Pengujian unit menggunakan Vitest, mencakup tiga area di
#link("../../03_Source_Code/backend/src/__tests__/")[`src/__tests__/`]:

- *Services*: `auth`, `case`, `comment`, `consensus`, `image`, `patient`,
  `review`, `validation`, dan `storage/supabase`.
- *Utils*: `crypto` (enkripsi AES), `hash` (bcrypt), `jwt`, `signature` (RSA),
  `access` (isolasi institusi), `pagination`.
- *Validations*: schema Zod tiap domain.

Rincian hasil eksekusi terdapat pada
#link("../../05_Testing/Hasil%20Unit%20Testing.pdf")[`05_Testing/Hasil Unit Testing.pdf`].
Cakupan ini memastikan kontrol keamanan kritis (kripto, hashing, JWT, isolasi)
terverifikasi secara otomatis, bukan hanya secara manual.

== Pengujian Skenario Serangan

Delapan skenario merepresentasikan vektor ancaman utama. Tiap skenario
mendefinisikan kondisi payload anomali, kode HTTP yang diharapkan, dan kriteria
lulus yang objektif.

#figure(
  table(
    columns: (auto, 1fr, 1fr, auto, auto, auto),
    align: (left, left, left, center, center, center),
    inset: 6pt,
    stroke: 0.5pt + rgb("#cccccc"),
    table.header([*ID*], [*Skenario*], [*Payload / Kondisi Uji*], [*Eksp.*], [*Aktual*], [*Hasil*]),
    [TC-01], [Akses rute tertutup tanpa token], [Header `Authorization: null`], [401], [401], [Lulus],
    [TC-02], [Token JWT kedaluwarsa], [Token berumur > 24 jam], [401], [401], [Lulus],
    [TC-03], [SQL Injection pada form auth], [`email: "admin' OR 1=1 --"`], [401], [401], [Lulus],
    [TC-04], [Brute-force / spam request login], [> 100 request beruntun < 15 menit], [429], [429], [Lulus],
    [TC-05], [Pelanggaran wewenang RBAC], [`GET /api/review/queue` dgn token Operator Lab], [403], [403], [Lulus],
    [TC-06], [Pelanggaran isolasi institusi], [Akses pasien institusi A pakai token institusi B], [403], [403], [Lulus],
    [TC-07], [Bypass validasi Zod], [`POST` pasien tanpa atribut `no_induk`], [400], [400], [Lulus],
    [TC-08], [Signed URL kedaluwarsa], [Akses tautan citra setelah > 15 menit], [403], [403], [Lulus],
  ),
  caption: [Hasil pengujian delapan skenario serangan.],
)

Seluruh request tidak sah berhasil diintersepsi middleware sebelum mencapai
_core business logic_. Dua mekanisme disorot khusus: rate limiting (TC-04
menghasilkan 429 saat simulasi beban tinggi) dan RBAC (TC-05 menghasilkan 403
saat simulasi _privilege escalation_).

#figure(
  image("image/test case.png", width: 100%),
  caption: [Respons HTTP 401/403/429 yang dikembalikan server pada skenario uji.],
)

== Analisis Dampak Kinerja

Pengukuran membandingkan kondisi sebelum dan sesudah penambahan lapisan keamanan
di lingkungan pengembangan lokal.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, right, right, right, right),
    inset: 7pt,
    stroke: 0.5pt + rgb("#cccccc"),
    table.header([*Metrik*], [*Sebelum*], [*Sesudah*], [*Δ*], [*Δ (%)*]),
    [Login RT], [219.4 ms], [291.8 ms], [+72.4 ms], [+33.0%],
    [Get Data RT], [0.8 ms], [1.4 ms], [+0.6 ms], [+75.0%],
    [Upload RT], [N/A], [N/A], [N/A], [N/A],
    [CPU Load/Login], [N/A], [72 ms/op], [+72 ms], [N/A],
    [Memory Heap], [6.6 MB], [8.1 MB], [+1.5 MB], [+22.7%],
  ),
  caption: [Dampak kinerja sebelum vs sesudah penambahan lapisan keamanan.],
)

Kenaikan waktu respons login sebesar +33,0% adalah konsekuensi terencana dari
bcrypt (_cost factor_ 10), yang memang dirancang menuntut komputasi CPU intensif
untuk memperlambat brute-force. Tambahan memori heap sebesar +1,5 MB
dialokasikan untuk middleware keamanan yang berjalan simultan (rate limiter,
verifikasi JWT, audit log). Secara keseluruhan _overhead_ tergolong minimal dan
dalam batas toleransi, sehingga keamanan tinggi tercapai tanpa mengorbankan
ketersediaan secara signifikan.

// =============================================================================
= Matriks Telusur (Traceability Matrix)
// =============================================================================

Matriks ini mengikat ancaman, kontrol, file, dan bukti uji, sehingga keamanan
dapat dibuktikan, bukan sekadar diklaim.

#figure(
  table(
    columns: (1.4fr, auto, 1fr, 1.2fr, 1.1fr),
    align: (left, left, left, left, left),
    inset: 6pt,
    stroke: 0.5pt + rgb("#cccccc"),
    table.header(
      [*Ancaman (STRIDE / OWASP)*], [*Aset terdampak*], [*Kontrol (§4)*],
      [*File implementasi*], [*Bukti uji*],
    ),
    [Spoofing identitas (API2)], [Sesi pengguna], [JWT auth (§4.1)],
      [`jwt.utils.ts`, `authenticate.middleware.ts`], [`jwt.utils.test.ts`; TC-01, TC-02],
    [Elevation of Privilege (API5)], [Operasi klinis], [RBAC (§4.2)],
      [`authenticate.middleware.ts`], [TC-05],
    [Information Disclosure kredensial (API2)], [Password], [bcrypt (§4.3)],
      [`hash.utils.ts`], [`hash.utils.test.ts`],
    [BOLA lintas institusi (API1)], [Data kasus/pasien], [Isolasi institusi (§4.4)],
      [`access.utils.ts`], [`access.utils.test.ts`; TC-06],
    [Tampering / Injection], [Semua input], [Validasi Zod (§4.5)],
      [`validate.middleware.ts`, `validations/`], [`*.validation.test.ts`; TC-07],
    [Spoofing via register/credential stuffing (API2)], [Akun], [No register + first-login (§4.6)],
      [`auth.service.ts`], [`auth.service.test.ts`],
    [Repudiation / Tampering diskusi], [Komentar klinis], [Soft delete + mask (§4.7)],
      [`comment.service.ts`], [`comment.service.test.ts`],
    [Information Disclosure berkas (API1)], [Citra & laporan], [Signed URL (§4.8)],
      [`supabase.storage.ts`], [`supabase.storage.test.ts`; TC-08],
    [Repudiation aksi], [Jejak aktivitas], [Audit log append-only (§4.9)],
      [`audit.utils.ts`], [(manual + log DB)],
    [Tampering laporan], [Laporan klinis], [Tanda tangan digital (§4.10)],
      [`report.service.ts`, `signature.utils.ts`], [`signature.utils.test.ts`],
    [Spoofing token reset (API2)], [Alur reset password], [Reset stateless (§4.11)],
      [`auth.service.ts`, `auth.types.ts`], [`auth.service.test.ts`],
    [Information Disclosure identitas], [NIK / BPJS], [AES-256 field-level (§4.12)],
      [`crypto.utils.ts`, `patient.service.ts`], [`crypto.utils.test.ts`],
    [Denial of Service (API4)], [Ketersediaan API], [Rate limiting (§4.13)],
      [`rate-limit.middleware.ts`], [TC-04],
  ),
  caption: [Matriks telusur ancaman, kontrol, file, dan bukti uji.],
)

#figure(
  image("image/Threat model.png", width: 100%),
  caption: [Ringkasan threat modelling sistem.],
)

// =============================================================================
= Batasan & Pengembangan Lanjutan
// =============================================================================

Sebagai bentuk objektivitas, berikut batasan sistem saat ini beserta ancaman
residualnya:

+ Tanda tangan digital masih simetris (SHA-256). Skema ini mampu mendeteksi
  perubahan isi laporan, tetapi belum mendukung verifikasi independen pihak
  ketiga. Rencana: migrasi ke RSA-2048 (RSA-SHA256) yang utilitasnya sudah
  tersedia di `signature.utils.ts` dan field `digital_signature` sudah disiapkan
  di skema.
+ AES-256-ECB tidak menyembunyikan pola data identik. Dipilih demi
  mempertahankan `@unique` constraint pada NIK/BPJS. Alternatif masa depan:
  AES-GCM dengan strategi indeks _blind index_ terpisah untuk pencarian.
+ JWT stateless tanpa refresh/revocation. Token tidak dapat dicabut sebelum
  kedaluwarsa (login 1 hari, reset 15 menit). Rencana: mekanisme _refresh token_
  dan daftar cabut (_denylist_).
+ bcrypt cost factor 10. Cukup untuk saat ini; perlu ditinjau berkala seiring
  naiknya daya komputasi penyerang.
+ QC citra masih di-mock (otomatis `PASSED`) dan inferensi AI via seeding,
  sedangkan endpoint dan _state machine_ sudah siap untuk integrasi nyata.
+ Pengujian kinerja masih lingkungan lokal. Belum diuji pada infrastruktur
  produksi skala besar dengan ribuan request konkuren.

// =============================================================================
= Lampiran
// =============================================================================

== Struktur Direktori (ringkas)

```
Projek Akhir KI/
├── 01_Proposal_&_Analisis/      # Proposal teknis & threat modelling
├── 02_Design_Documents/         # ERD, Architecture Diagram, Testing Plan
├── 03_Source_Code/backend/
│   ├── prisma/                  # schema.prisma, migrasi, seed
│   ├── scripts/                 # generate-rsa-keys.ts
│   └── src/
│       ├── config/              # prisma, supabase, swagger
│       ├── routes/              # endpoint per domain
│       ├── controller/          # handler HTTP
│       ├── services/            # logika bisnis & keamanan domain
│       │   └── storage/         # abstraksi Supabase Storage
│       ├── validations/         # Zod schema per domain
│       ├── middlewares/         # authenticate, validate, rate-limit, error-handler
│       ├── utils/               # jwt, hash, crypto (AES), signature (RSA), audit, access
│       └── __tests__/           # unit test (Vitest)
├── 04_Reports_&_Paper/          # Laporan akhir, paper ilmiah, progress report
└── 05_Testing/                  # Hasil unit testing
```

== Ringkasan Peran → Endpoint

#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    inset: 7pt,
    stroke: 0.5pt + rgb("#cccccc"),
    table.header([*Peran (enum kode)*], [*Label*], [*Akses utama*]),
    [`OPERATOR_LAB`], [Operator/Teknisi Lab],
      [Kelola pasien & kasus, upload citra, submit ke antrian],
    [`DOKTER_PATOLOGI`], [Dokter Patologi],
      [Review & validasi AI, komentar, consensus, generate & tanda tangan laporan],
    [`ADMIN_AI`], [Admin AI],
      [Monitoring sistem AI (belum diimplementasi)],
  ),
  caption: [Ringkasan peran dan akses utamanya.],
)

Catatan: pada paper, `OPERATOR_LAB` dirujuk sebagai "Teknisi Lab". Di dokumen
ini digunakan nama enum kode agar konsisten dengan implementasi (`Role` enum
di `schema.prisma`).
