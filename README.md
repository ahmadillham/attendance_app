# Absensi Kuliah

Sistem presensi mahasiswa berbasis mobile menggunakan **Flutter** + **Node.js/Express**.

---

## 1. Menjalankan Project

Cara termudah dan paling direkomendasikan untuk menjalankan backend dan frontend sekaligus adalah dengan script `dev.sh`.

```bash
# Jalankan di root direktori project
./dev.sh
# Atau
FLUTTER_MODE=--profile ./dev.sh
```

Atau jika Anda ingin menjalankannya secara manual di terminal terpisah:

```bash
# Terminal 1 (Backend)
cd backend
npm run dev

# Terminal 2 (Frontend)
cd frontend
flutter run

# (Jika pakai HP fisik Android, jalankan ini di terminal agar frontend bisa terkoneksi ke localhost backend)
adb reverse tcp:3000 tcp:3000
```

---

## 2. Reset Database

Jika Anda ingin menghapus seluruh data dan mereset tabel ke kondisi awal, jalankan perintah berikut:

```bash
cd backend
npx prisma migrate reset --force
```
*(Catatan: Perintah ini akan menghapus semua data, membuat ulang tabel, dan otomatis menjalankan proses seeding).*

---

## 3. Seeding Database

Jika Anda hanya ingin menjalankan seeding ulang (menambahkan data mahasiswa, dosen, absen, dll) tanpa menghapus struktur tabel, jalankan:

```bash
cd backend
npx prisma db seed
```

# kill port
```bash
lsof -ti :3000 | xargs -r kill -9
```
