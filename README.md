# Absensi Kuliah

Sistem presensi mahasiswa berbasis mobile menggunakan **Flutter** + **Node.js/Express**.

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
