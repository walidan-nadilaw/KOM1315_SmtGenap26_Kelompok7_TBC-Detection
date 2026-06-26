# Rencana Pengujian Integrasi Protokol AAA (Testing Plan)
**Proyek:** Sistem Manajemen Lab & Skrining Awal Tuberkulosis (TBC)  
**Fokus Pengujian:** Keamanan Backend - Otentikasi, Otorisasi, dan Akuntabilitas (AAA)

---

## 1. Pendahuluan
Dokumen ini mendeskripsikan skenario pengujian terstruktur untuk memverifikasi integrasi protokol keamanan AAA (*Authentication, Authorization, Accounting*) pada arsitektur *backend*. Pengujian ini bertujuan untuk membuktikan bahwa sistem dapat mengidentifikasi pengguna secara akurat, membatasi hak akses sesuai wewenang, dan mencatat setiap aktivitas secara permanen guna memenuhi standar nirsangkal (*non-repudiation*).

---

## 2. Rencana Uji Autentikasi (*Authentication*)
**Tujuan:** Memastikan sistem mengenali pengguna yang sah menggunakan JWT dan melindungi kredensial dengan Bcrypt.

| ID | Skenario Pengujian | Langkah Pengujian (Payload/Aksi) | Hasil yang Diharapkan (Ekspektasi) |
|:---|:---|:---|:---|
| **AUTH-01** | Login dengan kredensial valid | POST `/api/auth/login` dengan *email* & *password* benar. | HTTP 200 OK. Mengembalikan token JWT yang valid. |
| **AUTH-02** | Login dengan kata sandi salah | POST `/api/auth/login` dengan kata sandi acak. | HTTP 401 Unauthorized. Login ditolak. |
| **AUTH-03** | Akses *endpoint* tertutup tanpa token | Memanggil `GET /api/patients` tanpa *header* `Authorization`. | HTTP 401 Unauthorized. Akses ditolak. |
| **AUTH-04** | Akses dengan token kedaluwarsa | Menggunakan token JWT yang umurnya sudah melewati batas 24 jam. | HTTP 401 Unauthorized. Token ditolak. |
| **AUTH-05** | Mitigasi injeksi SQL pada form login | POST `/api/auth/login` dengan payload: `"email": "admin' OR 1=1 --"` | HTTP 401 Unauthorized. Sistem memblokir karakter anomali. |

---

## 3. Rencana Uji Otorisasi (*Authorization*)
**Tujuan:** Memastikan penegakan *Role-Based Access Control* (RBAC) dan isolasi data multitenant (*Institution Isolation*) berfungsi tanpa celah.

| ID | Skenario Pengujian | Langkah Pengujian (Payload/Aksi) | Hasil yang Diharapkan (Ekspektasi) |
|:---|:---|:---|:---|
| **AUTHZ-01** | *Bypass* wewenang beda tingkat | *Login* sebagai Teknisi Lab, mencoba memanggil `GET /api/review/queue` (Rute khusus Dokter). | HTTP 403 Forbidden. Akses ditolak lapis *Middleware*. |
| **AUTHZ-02** | Isolasi Multitenant (Beda Faskes) | Dokter dari RS "A" mencoba melihat profil Pasien dari RS "B" via `GET /api/patients/:id`. | HTTP 403 Forbidden. Fungsi `assertSameInstitution` memblokir akses. |
| **AUTHZ-03** | Akses file tanpa *Presigned URL* | Mengakses langsung URL objek citra di Supabase tanpa token URL khusus. | Akses ditolak oleh konfigurasi *Bucket* (HTTP 4xx). |
| **AUTHZ-04** | Kedaluwarsa *Presigned URL* | Mengakses *Presigned URL* gambar medis yang umurnya melebihi 15 menit. | HTTP 403 Forbidden dari sisi Supabase Storage. |

---

## 4. Rencana Uji Akuntabilitas (*Accounting/Traceability*)
**Tujuan:** Memastikan semua aktivitas tercatat secara permanen di dalam *Audit Log* (*append-only*) dan lalu lintas HTTP terekam oleh *Morgan Logger*.

| ID | Skenario Pengujian | Langkah Pengujian (Payload/Aksi) | Hasil yang Diharapkan (Ekspektasi) |
|:---|:---|:---|:---|
| **ACC-01** | Pencatatan mutasi entitas Pasien | *Login* sebagai Operator, lalu POST `/api/patients` untuk menambah pasien baru. | Database `AuditLog` bertambah 1 baris. Mencatat `user_id`, aksi `CREATE`, entitas `Patient`. |
| **ACC-02** | Pencatatan pengesahan Laporan | *Login* sebagai Dokter, lalu melakukan finalisasi dokumen laporan. | Database `AuditLog` mencatat aksi `SIGN_REPORT` dengan `entity_id` yang cocok. |
| **ACC-03** | Uji kekebalan (Immutability) Log | Secara programatik memanggil instruksi `UPDATE` atau `DELETE` pada baris di tabel `AuditLog`. | Sistem menolak / tidak menyediakan fungsi API apa pun untuk menghapus log (hanya-tambah). |
| **ACC-04** | Pencatatan lalulintas jaringan | Melakukan *request* dari Postman, lalu memeriksa panel terminal peladen. | *Morgan Logger* memunculkan rekaman *real-time* (Method, URL, Status Code, Response Time). |

---

## 5. Prasyarat Pengujian Lingkungan (*Environment Setup*)
- Pengujian dilakukan menggunakan lingkungan uji lokal (*development*) menggunakan **Postman** atau utilitas pengujian seperti **Vitest**.
- Diperlukan akses ke dasbor database (Supabase) untuk memvalidasi rekaman tabel `AuditLog`.
- Server harus berjalan aktif (`npm run dev`) untuk melihat tangkapan *Morgan Logger* secara *real-time*.

*(Dokumen ini akan digunakan sebagai rujukan untuk memvalidasi keamanan arsitektur sistem pada fase demo / pelaporan akhir)*
