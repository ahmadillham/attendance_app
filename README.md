# Absensi Kuliah — Dokumentasi Proyek

Sistem presensi mahasiswa berbasis mobile yang mengintegrasikan **Flutter** (frontend) dengan **Node.js/Express** (backend) menggunakan autentikasi berbasis JWT, verifikasi wajah, dan validasi geofencing GPS.

---

## Daftar Isi

1. [Gambaran Umum](#gambaran-umum)
2. [Arsitektur Sistem](#arsitektur-sistem)
3. [Struktur Proyek](#struktur-proyek)
4. [Persyaratan Sistem](#persyaratan-sistem)
5. [Panduan Instalasi](#panduan-instalasi)
6. [Konfigurasi Lingkungan](#konfigurasi-lingkungan)
7. [Menjalankan Aplikasi](#menjalankan-aplikasi)
8. [API Reference](#api-reference)
9. [Model Database](#model-database)
10. [Arsitektur Frontend](#arsitektur-frontend)
11. [Alur Autentikasi](#alur-autentikasi)
12. [Keamanan](#keamanan)

---

## Gambaran Umum

**Absensi Kuliah** adalah aplikasi presensi digital yang dirancang untuk mahasiswa Universitas Nahdlatul Ulama Sunan Giri. Mahasiswa dapat melakukan absensi melalui smartphone dengan validasi berlapis:

- 🔐 **Autentikasi JWT** — Login dengan NIM dan password
- 📍 **Geofencing GPS** — Validasi lokasi dalam radius 200m dari kampus
- 👤 **Verifikasi Wajah** — Face recognition via face-api.js (opsional)
- 🧬 **Biometrik** — Login dengan sidik jari / Face ID setelah login pertama

---

## Arsitektur Sistem

```
┌─────────────────────────────────┐     HTTP/REST      ┌──────────────────────────────────┐
│        Flutter App (Android)    │ ◄────────────────► │   Node.js / Express Backend      │
│                                 │                     │                                  │
│  • Provider state management    │                     │  • JWT authentication            │
│  • Biometric auth (local_auth)  │                     │  • Prisma ORM (MariaDB adapter)  │
│  • Camera (face capture)        │                     │  • MySQL 8 database              │
│  • GPS (geolocator)             │                     │  • Multer file upload            │
│  • Secure storage (credentials) │                     │  • face-api.js (bypass mode)     │
└─────────────────────────────────┘                     └──────────────────────────────────┘
```

---

## Struktur Proyek

```
absen flutter/
├── frontend/                          # Aplikasi Flutter
│   ├── lib/
│   │   ├── main.dart                  # Entry point & routing
│   │   ├── constants/
│   │   │   ├── theme.dart             # Design system (warna, tipografi)
│   │   │   └── mock_data.dart         # Data dummy (hanya debug mode)
│   │   ├── models/
│   │   │   ├── student.dart           # Model mahasiswa + attendance summary
│   │   │   ├── schedule.dart          # Model jadwal kuliah
│   │   │   ├── attendance.dart        # Model absensi & rekapitulasi
│   │   │   └── leave_request.dart     # Model pengajuan izin
│   │   ├── services/
│   │   │   └── api_service.dart       # HTTP client, token & credential management
│   │   ├── providers/
│   │   │   └── app_provider.dart      # Global state (Provider pattern)
│   │   ├── screens/
│   │   │   ├── splash_screen.dart     # Auth check + token expiry validation
│   │   │   ├── login_screen.dart      # Login NIM/password + biometrik
│   │   │   ├── dashboard_screen.dart  # Beranda utama
│   │   │   ├── attendance_screen.dart # Capture wajah + GPS absensi
│   │   │   ├── history_screen.dart    # Riwayat absensi per mata kuliah
│   │   │   ├── schedule_screen.dart   # Jadwal mingguan
│   │   │   ├── leave_request_screen.dart  # Form pengajuan izin
│   │   │   ├── leave_history_screen.dart  # Riwayat pengajuan izin
│   │   │   ├── profile_screen.dart    # Profil & ganti password
│   │   │   └── face_register_screen.dart  # Pendaftaran data wajah
│   │   └── widgets/
│   │       ├── screen_header.dart     # Header komponen reusable
│   │       └── section_label.dart     # Label seksi reusable
│   └── pubspec.yaml
│
└── backend/                           # Backend Node.js
    ├── src/
    │   ├── index.js                   # Entry point, middleware, routing
    │   ├── routes/
    │   │   ├── authRoutes.js          # POST /register, POST /login
    │   │   ├── attendanceRoutes.js    # POST /, GET /history
    │   │   ├── scheduleRoutes.js      # GET /, GET /:id
    │   │   ├── leaveRoutes.js         # POST /, GET /
    │   │   ├── profileRoutes.js       # GET /, PUT /password
    │   │   └── faceRoutes.js          # POST /register, GET /status
    │   ├── controllers/
    │   │   ├── authController.js
    │   │   └── profileController.js
    │   ├── middlewares/
    │   │   ├── authMiddleware.js      # JWT verification
    │   │   ├── uploadMiddleware.js    # Multer config
    │   │   └── errorHandler.js
    │   ├── lib/
    │   │   ├── prisma.js              # Prisma client (MariaDB adapter)
    │   │   ├── faceDescriptor.js      # face-api.js model loading
    │   │   └── faceVerify.js          # Euclidean distance face comparison
    │   └── validations/
    │       ├── authValidation.js
    │       └── attendanceValidation.js
    ├── prisma/
    │   ├── schema.prisma              # Database schema
    │   └── seed.js                    # Data awal (1 mahasiswa, 7 mata kuliah)
    ├── prisma.config.ts               # Konfigurasi Prisma 7
    └── .env                           # Variabel lingkungan
```

---

## Persyaratan Sistem

### Backend
| Komponen | Versi |
|----------|-------|
| Node.js | ≥ 20 |
| MySQL | 8.x (via Docker atau native) |
| npm | ≥ 10 |

### Frontend
| Komponen | Versi |
|----------|-------|
| Flutter SDK | ≥ 3.11.4 |
| Dart SDK | ≥ 3.11.4 |
| Android SDK | API 21+ (Android 5.0) |

---

## Panduan Instalasi

### 1. Backend

```bash
cd backend

# Install dependensi
npm install

# Buat file .env (lihat bagian Konfigurasi)
cp .env.example .env

# Jalankan migrasi database
npx prisma migrate deploy

# (Opsional) Isi data awal
npx prisma db seed
```

### 2. Frontend

```bash
cd frontend

# Install dependensi Flutter
flutter pub get

# (Opsional) Cek perangkat yang tersambung
flutter devices
```

---

## Konfigurasi Lingkungan

### Backend — `backend/.env`

```env
PORT=3000
DATABASE_URL="mysql://root:PASSWORD@localhost:3306/absen_flutter"
TOKEN_SECRET="your-secret-key-min-32-chars"
```

> **Catatan:** JWT token berlaku selama **1 hari**. Ganti `PASSWORD` dengan password MySQL Anda.

#### Jika menggunakan MySQL 8 via Docker

Pastikan `prisma.js` menggunakan `allowPublicKeyRetrieval: true` agar adapter dapat mengautentikasi menggunakan `caching_sha2_password`:

```javascript
const adapter = new PrismaMariaDb({
  host, port, user, password, database,
  allowPublicKeyRetrieval: true,  // Wajib untuk MySQL 8
});
```

### Frontend — URL Backend

URL backend dapat dikonfigurasi **tanpa mengubah kode** menggunakan `--dart-define`:

```bash
# Development (default: 192.168.1.21)
flutter run --dart-define=API_URL=http://192.168.1.x:3000/api

# Emulator Android
flutter run --dart-define=API_URL=http://10.0.2.2:3000/api

# Produksi
flutter build apk --dart-define=API_URL=https://api.yourdomain.com/api
```

---

## Menjalankan Aplikasi

### Backend

```bash
cd backend

# Mode development (hot reload via nodemon)
npm run dev

# Mode produksi
npm start
```

Verifikasi server berjalan:
```bash
curl http://localhost:3000/api/health
# {"status":"ok","message":"Absensi Backend API is running"}
```

### Frontend

```bash
cd frontend

# Jalankan di perangkat fisik (pastikan seip WiFi sama dengan laptop)
flutter run --dart-define=API_URL=http://192.168.1.21:3000/api

# Jalankan di emulator
flutter run --dart-define=API_URL=http://10.0.2.2:3000/api
```

### Akun Default (setelah seed)

| Field | Nilai |
|-------|-------|
| NIM / Student ID | `241101052` |
| Password | `Password123` |
| Nama | Ahmad Bahrudin Ilham |

---

## API Reference

Semua endpoint kecuali `/auth` memerlukan header:
```
Authorization: Bearer <jwt_token>
```

### Autentikasi

| Method | Endpoint | Deskripsi | Auth |
|--------|----------|-----------|------|
| `POST` | `/api/auth/register` | Daftarkan mahasiswa baru | ❌ |
| `POST` | `/api/auth/login` | Login, mendapat JWT token | ❌ |
| `GET`  | `/api/health` | Cek status server | ❌ |

#### POST `/api/auth/login`
```json
// Request
{ "studentId": "241101052", "password": "Password123" }

// Response 200
{ "token": "eyJhbGci...", "studentId": "241101052", "name": "Ahmad Bahrudin Ilham" }

// Response 400
{ "message": "Student ID not found" }
{ "message": "Invalid password" }
```

---

### Absensi

| Method | Endpoint | Deskripsi |
|--------|----------|-----------|
| `POST` | `/api/attendance` | Submit absensi (multipart/form-data) |
| `GET`  | `/api/attendance/history` | Riwayat absensi mahasiswa |

#### POST `/api/attendance` — `multipart/form-data`
| Field | Tipe | Wajib | Keterangan |
|-------|------|-------|------------|
| `courseId` | string | ✅ | ID mata kuliah |
| `status` | string | ✅ | `present`, `absent`, `leave` |
| `latitude` | number | ✅ | Koordinat GPS mahasiswa |
| `longitude` | number | ✅ | Koordinat GPS mahasiswa |
| `meetingCount` | number | ❌ | Auto-hitung jika tidak diisi |
| `faceImage` | file | ✅ | Foto wajah untuk verifikasi |

**Validasi keamanan yang dilakukan:**
1. Verifikasi JWT token
2. Validasi enrollment (mahasiswa terdaftar di mata kuliah)
3. Verifikasi wajah via face-api.js (bypass mode jika model tidak tersedia)
4. Geofencing — radius 200m dari koordinat kampus (`-7.167311, 111.892951`)
5. Cek duplikasi absensi per pertemuan

---

### Jadwal

| Method | Endpoint | Deskripsi |
|--------|----------|-----------|
| `GET` | `/api/schedules` | Semua jadwal hari ini |
| `GET` | `/api/schedules?dayOfWeek=Senin` | Jadwal hari tertentu |

Nilai `dayOfWeek` yang valid: `Senin`, `Selasa`, `Rabu`, `Kamis`, `Jumat`, `Sabtu`

---

### Izin / Cuti

| Method | Endpoint | Deskripsi |
|--------|----------|-----------|
| `POST` | `/api/leave-requests` | Ajukan izin (multipart/form-data) |
| `GET`  | `/api/leave-requests` | Riwayat pengajuan izin |

#### POST `/api/leave-requests` — `multipart/form-data`
| Field | Tipe | Wajib |
|-------|------|-------|
| `reason` | string | ✅ |
| `description` | string | ❌ |
| `dateFrom` | string (ISO date) | ✅ |
| `dateTo` | string (ISO date) | ✅ |
| `document` | file | ❌ |

---

### Profil

| Method | Endpoint | Deskripsi |
|--------|----------|-----------|
| `GET` | `/api/profile` | Data profil mahasiswa |
| `PUT` | `/api/profile/password` | Ganti password |

#### PUT `/api/profile/password`
```json
{ "oldPassword": "Password123", "newPassword": "NewPassword456" }
```

---

### Face Recognition

| Method | Endpoint | Deskripsi |
|--------|----------|-----------|
| `POST` | `/api/face/register` | Daftarkan data wajah |
| `GET`  | `/api/face/status` | Cek status pendaftaran wajah |

---

## Model Database

```prisma
model Student {
  id             String         // UUID primary key
  studentId      String         // NIM (unik)
  name           String
  email          String         // unik
  phone          String?
  department     String         // Program studi
  faculty        String
  semester       Int
  password       String         // bcrypt hashed
  faceDescriptor Json?          // Array 128D float (face-api.js)
  attendances    Attendance[]
  leaveRequests  LeaveRequest[]
  enrollments    Enrollment[]
}

model Course {
  code       String    // Kode MK (unik)
  name       String
  lecturer   String
  schedules  Schedule[]
  attendances Attendance[]
  enrollments Enrollment[]
}

model Attendance {
  status       AttendanceStatus  // present | absent | leave
  meetingCount Int               // Pertemuan ke-N
  date         DateTime
  studentId    String
  courseId     String
  // Constraint: unique(studentId, courseId, meetingCount)
}

model LeaveRequest {
  reason      String
  description String?
  evidenceUrl String?           // Path file dokumen bukti
  status      LeaveStatus       // PENDING | APPROVED | REJECTED
  dateFrom    DateTime
  dateTo      DateTime
  studentId   String
}

model Schedule {
  dayOfWeek  DayOfWeek   // Senin–Sabtu
  startTime  String      // Format "HH:mm"
  endTime    String
  room       String
  courseId   String
}
```

---

## Arsitektur Frontend

### State Management

Aplikasi menggunakan **Provider pattern**. `AppProvider` adalah satu-satunya provider global yang menyimpan:

```dart
class AppProvider extends ChangeNotifier {
  // Data
  DashboardData? dashboardData;
  List<CourseAttendance> attendanceHistory;
  Student? profile;
  List<LeaveRequest> leaveHistory;

  // Error states (terisolasi per domain)
  String? dashboardError;
  String? historyError;
  String? profileError;
  String? leaveError;

  // Loading states
  bool isLoadingDashboard;
  bool isLoadingHistory;
  // ...
}
```

### Alur Data

```
Screen → AppProvider → ApiService → Backend API
                    ↑
               notifyListeners()
```

### Model Utama

| Model | File | Keterangan |
|-------|------|------------|
| `Student` | `models/student.dart` | Data mahasiswa + `AttendanceSummary` |
| `ScheduleItem` | `models/schedule.dart` | Satu slot jadwal |
| `CourseAttendance` | `models/attendance.dart` | Rekapitulasi per mata kuliah |
| `LeaveRequest` | `models/leave_request.dart` | Pengajuan izin |
| `DashboardData` | `services/api_service.dart` | Agregat data dashboard |

---

## Alur Autentikasi

```
Buka App
    │
    ▼
SplashScreen._checkAuth()
    ├── Token ada & valid (exp belum lewat)? ──► /main
    ├── Token expired, ada saved credentials? ──► loginWithSavedCredentials() ──► /main
    └── Tidak ada sesi ────────────────────────► /login

/login
    ├── Login NIM + Password
    │       ├── POST /api/auth/login ──► simpan JWT token
    │       └── Simpan NIM+password di FlutterSecureStorage
    │               └──► /main
    │
    └── Login Sidik Jari / Face ID
            ├── Cek hasSavedCredentials()
            │       └── Tidak ada ──► tampilkan peringatan
            ├── Autentikasi biometrik (local_auth)
            └── loginWithSavedCredentials() ──► /main
```

---

## Keamanan

### Validasi Absensi (4 Lapis)

| Layer | Mekanisme | Keterangan |
|-------|-----------|------------|
| 1 | JWT Token | Semua endpoint dilindungi middleware |
| 2 | Enrollment Check | Student hanya bisa absen di MK yang diambil |
| 3 | Geofencing | Radius 200m dari kampus (Haversine formula) |
| 4 | Face Verification | Euclidean distance dari 128D face descriptor |

### Penyimpanan Credential

- **JWT Token** → `SharedPreferences` (sesi aktif)
- **NIM + Password** → `FlutterSecureStorage` (re-auth biometrik, terenkripsi di Keystore Android)
- **Token dihapus** saat logout, **credential tetap** untuk biometrik

### Catatan Keamanan

> [!WARNING]
> **Face recognition berjalan dalam BYPASS MODE** saat modul `@tensorflow/tfjs-node` tidak terinstal. Absensi tetap dapat dilakukan tanpa verifikasi wajah. Untuk produksi, instal dependensi tersebut:
> ```bash
> npm install @tensorflow/tfjs-node
> ```

> [!NOTE]
> Mock data fallback (`kUseMockFallback`) hanya aktif di debug build (`flutter run`). Pada release build (`flutter build apk`), error API akan ditampilkan ke pengguna, bukan diganti data palsu.
