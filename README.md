# Absensi Kuliah

Sistem presensi mahasiswa berbasis mobile menggunakan **Flutter** + **Node.js/Express** dengan verifikasi wajah, geofencing GPS, dan manajemen perizinan dua arah (mahasiswa ↔ dosen).

---

## Fitur Utama

### Mahasiswa
- **Absensi** — Verifikasi wajah + GPS dengan liveness detection
- **Screen Flash** — Layar putih + brightness maksimal untuk pencahayaan minim
- **Pengajuan Izin** — Sakit / Kegiatan Akademik / Keluarga, dengan upload dokumen
- **Riwayat** — Statistik hadir, absen, izin per mata kuliah
- **Biometrik** — Login sidik jari / Face ID setelah login pertama
- **Mock Time** — Simulasi waktu untuk testing (5x tap background di login)

### Dosen
- **Dashboard** — Ringkasan mata kuliah yang diampu
- **Rekap Absensi** — Daftar kehadiran per mahasiswa per mata kuliah
- **Kelola Izin** — Approve / Reject pengajuan izin mahasiswa
- **Profil** — Ganti password

---

## Tech Stack

| Layer | Teknologi |
|-------|-----------|
| Frontend | Flutter 3.11+, Provider, Camera, Geolocator |
| Backend | Node.js 20+, Express, Prisma 7, JWT |
| Database | MySQL 8 (via Prisma MariaDB adapter) |
| Face Recognition | @vladmandic/face-api (SSD Mobilenet + 128D embedding) |

---

## Quick Start

### 1. Setup Database

```bash
# Jalankan MySQL 8 (contoh via Docker)
docker run -d --name mysql8 -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=absen_flutter \
  mysql:8
```

### 2. Setup Backend

```bash
cd backend
npm install

# Buat file .env
cat > .env << EOF
PORT=3000
DATABASE_URL="mysql://root:root@localhost:3306/absen_flutter"
TOKEN_SECRET="your-secret-key-minimum-32-characters-long"
EOF

# Migrasi + seed database
npx prisma migrate reset --force
```

### 3. Setup Frontend

```bash
cd frontend
flutter pub get
```

### 4. Jalankan

```bash
# Cara cepat (backend + frontend sekaligus)
./dev.sh

# Atau manual:
cd backend && npm run dev     # Terminal 1
cd frontend && flutter run    # Terminal 2

# Jika pakai HP fisik, jalankan dulu:
adb reverse tcp:3000 tcp:3000
```

---

## Akun Default

Semua akun menggunakan password: **`Password123`**

### Mahasiswa

| NIM | Nama |
|-----|------|
| `241101052` | Ahmad Bahrudin Ilham |

### Dosen

| NIDN | Nama | Mata Kuliah |
|------|------|-------------|
| `198501012001` | Dr. Mivan Ariful Fathoni, M.Si | Logika Matematika |
| `198501012002` | Muhammad Jauhar Fikri, S.Kom., M.Kom | Analisis Dan Desain Perangkat Lunak |
| `198501012003` | Guruh Putro Digantoro, S.Kom., M.Kom | Pemrograman Mikrokontroller |
| `198501012004` | Zakki Alawi, S.Kom., MM | Pemrograman Berbasis Mobile |
| `198501012005` | Dwi Issadari Hastuti, S.Pd., S.Kom., M.Kom | Interaksi Manusia & Komputer |
| `198501012006` | Mula Agung Barata, S.ST., M.Kom | Internet Of Things |
| `198501012007` | Afnil Efan Pajri, S.Kom., M.I.Kom | Komputasi Paralel Dan Terdistribusi |

> **Dev Mode Quick Login** — Di halaman login, terdapat dropdown "Mahasiswa" dan "Dosen" untuk login cepat tanpa mengetik.

---

## Reset Database

```bash
cd backend
npx prisma migrate reset --force
```

Perintah ini akan menghapus semua data, membuat ulang tabel, dan menjalankan seed otomatis.

---

## Struktur Proyek

```
absen flutter/
├── dev.sh                              # Script start all-in-one
├── frontend/
│   └── lib/
│       ├── main.dart                   # Entry point & routing
│       ├── constants/
│       │   ├── theme.dart              # Design system
│       │   └── mock_data.dart          # Data fallback (debug only)
│       ├── models/                     # Data models
│       ├── services/
│       │   ├── api_service.dart        # HTTP client & token management
│       │   └── app_time.dart           # Mock time system
│       ├── providers/
│       │   ├── app_provider.dart       # State mahasiswa
│       │   └── lecturer_provider.dart  # State dosen
│       └── screens/
│           ├── login_screen.dart       # Login + biometrik + quick login
│           ├── dashboard_screen.dart   # Beranda mahasiswa
│           ├── attendance_screen.dart  # Absensi (kamera + GPS + flash)
│           ├── history_screen.dart     # Riwayat absensi
│           ├── schedule_screen.dart    # Jadwal mingguan
│           ├── leave_request_screen.dart    # Form izin
│           ├── leave_history_screen.dart    # Riwayat izin
│           ├── profile_screen.dart     # Profil mahasiswa
│           ├── face_register_screen.dart    # Daftar wajah
│           └── lecturer/
│               ├── lecturer_dashboard_screen.dart
│               ├── course_attendance_screen.dart
│               ├── manage_leave_screen.dart
│               └── lecturer_profile_screen.dart
│
└── backend/
    ├── src/
    │   ├── index.js                    # Entry point
    │   ├── routes/
    │   │   ├── authRoutes.js           # Login & register
    │   │   ├── attendanceRoutes.js     # Absensi & riwayat
    │   │   ├── scheduleRoutes.js       # Jadwal
    │   │   ├── leaveRoutes.js          # Izin (mahasiswa)
    │   │   ├── lecturerRoutes.js       # Semua API dosen
    │   │   ├── profileRoutes.js        # Profil mahasiswa
    │   │   └── faceRoutes.js           # Registrasi wajah
    │   ├── middlewares/
    │   │   ├── authMiddleware.js       # JWT verification
    │   │   ├── studentMiddleware.js    # Role check: student
    │   │   ├── lecturerMiddleware.js   # Role check: lecturer
    │   │   └── uploadMiddleware.js     # Multer config
    │   └── lib/
    │       ├── prisma.js               # Prisma client
    │       ├── faceDescriptor.js       # Face embedding extraction
    │       └── faceVerify.js           # Cosine similarity comparison
    └── prisma/
        ├── schema.prisma               # Database schema
        └── seed.js                     # Data awal
```

---

## API Endpoints

Semua endpoint (kecuali `/auth`) memerlukan header: `Authorization: Bearer <token>`

### Auth
| Method | Endpoint | Deskripsi |
|--------|----------|-----------|
| `POST` | `/api/auth/login` | Login (NIM/NIDN + password) |
| `POST` | `/api/auth/register` | Daftar mahasiswa baru |

### Mahasiswa
| Method | Endpoint | Deskripsi |
|--------|----------|-----------|
| `POST` | `/api/attendance` | Submit absensi (multipart) |
| `GET` | `/api/attendance/history` | Riwayat (hadir + izin + absen) |
| `GET` | `/api/schedules` | Jadwal kuliah |
| `POST` | `/api/leave-requests` | Ajukan izin (multipart) |
| `GET` | `/api/leave-requests` | Riwayat izin |
| `GET` | `/api/profile` | Data profil |
| `PUT` | `/api/profile/password` | Ganti password |
| `POST` | `/api/face/register` | Daftar wajah (multipart) |
| `GET` | `/api/face/status` | Status registrasi wajah |

### Dosen
| Method | Endpoint | Deskripsi |
|--------|----------|-----------|
| `GET` | `/api/lecturer/dashboard` | Dashboard dosen |
| `GET` | `/api/lecturer/courses` | Daftar mata kuliah diampu |
| `GET` | `/api/lecturer/courses/:id/attendance` | Rekap absensi per MK |
| `PUT` | `/api/lecturer/attendance/:id` | Edit status kehadiran |
| `GET` | `/api/lecturer/leave-requests` | Daftar izin masuk |
| `PUT` | `/api/lecturer/leave-requests/:id` | Approve/Reject izin |
| `GET` | `/api/lecturer/profile` | Profil dosen |
| `PUT` | `/api/lecturer/profile/password` | Ganti password |

---

## Validasi Absensi (4 Lapis)

| # | Layer | Keterangan |
|---|-------|------------|
| 1 | JWT Token | Autentikasi pengguna |
| 2 | Enrollment | Mahasiswa terdaftar di mata kuliah |
| 3 | Geofencing | Radius 200m dari kampus (Haversine) |
| 4 | Face Verification | Cosine similarity 128D descriptor (threshold 0.75) |

---

## Catatan

- **Face recognition** berjalan dalam bypass mode jika `@tensorflow/tfjs-node` tidak terinstal
- **Liveness detection** menggunakan pergerakan landmark wajah antar-frame (threshold 8px)
- **Screen flash** menggunakan package `screen_brightness` untuk kontrol brightness
- **Mock time** hanya aktif di debug build, tidak berpengaruh di release build
