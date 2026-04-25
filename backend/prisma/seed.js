require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { PrismaMariaDb } = require('@prisma/adapter-mariadb');
const bcrypt = require('bcryptjs');

// Parse DATABASE_URL for adapter
function parseDatabaseUrl(url) {
    const parsed = new URL(url);
    return {
        host: parsed.hostname,
        port: parseInt(parsed.port) || 3306,
        user: decodeURIComponent(parsed.username),
        password: decodeURIComponent(parsed.password),
        database: parsed.pathname.replace('/', ''),
    };
}

const dbConfig = parseDatabaseUrl(process.env.DATABASE_URL);
const adapter = new PrismaMariaDb({
    host: dbConfig.host,
    port: dbConfig.port,
    user: dbConfig.user,
    password: dbConfig.password,
    database: dbConfig.database,
    allowPublicKeyRetrieval: true,
});
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('🌱 Memulai proses seeding database...');

  // 1. Simulasi Matriks Wajah 128D (Face Descriptor)
  const mockFaceDescriptor = Array.from({ length: 128 }, () => Math.random() * 0.2 - 0.1);

  // 2. Hash Password Standar
  const salt = await bcrypt.genSalt(10);
  const hashedPassword = await bcrypt.hash('Password123', salt);

  // 3. Memasukkan / Memperbarui Akun Mahasiswa
  const student = await prisma.student.upsert({
    where: { studentId: '241101052' },
    update: {
       faceDescriptor: mockFaceDescriptor,
       password: hashedPassword,
    },
    create: {
      studentId: '241101052',
      name: 'Ahmad Bahrudin Ilham',
      email: 'ahmadbhdilham@gmail.com',
      phone: '0812-2001-2661',
      department: 'Teknik Informatika',
      faculty: 'Fakultas Sains dan Teknologi',
      semester: 4,
      password: hashedPassword,
      faceDescriptor: mockFaceDescriptor,
    }
  });

  console.log(`✅ Profil Mahasiswa: ${student.name} (Sandi: Password123)`);

  // 4. Memasukkan / Memperbarui Akun Dosen
  const lecturersData = [
    { id: '198501012001', name: 'Dr. Mivan Ariful Fathoni, M.Si' },
    { id: '198501012002', name: 'Muhammad Jauhar Fikri, S.Kom., M.Kom' },
    { id: '198501012003', name: 'Guruh Putro Digantoro, S.Kom., M.Kom' },
    { id: '198501012004', name: 'Zakki Alawi, S.Kom., MM' },
    { id: '198501012005', name: 'Dwi Issadari Hastuti, S.Pd., S.Kom., M.Kom' },
    { id: '198501012006', name: 'Mula Agung Barata, S.ST., M.Kom' },
    { id: '198501012007', name: 'Afnil Efan Pajri, S.Kom., M.I.Kom' },
  ];

  const lecturersMap = {};
  for (const l of lecturersData) {
    const emailPrefix = l.name.toLowerCase().replace(/[^a-z0-9]/g, '').substring(0, 10);
    const lecturer = await prisma.lecturer.upsert({
      where: { lecturerId: l.id },
      update: { password: hashedPassword },
      create: {
        lecturerId: l.id,
        name: l.name,
        email: `${emailPrefix}@unuha.ac.id`,
        phone: '0813-3000-1234',
        department: 'Teknik Informatika',
        faculty: 'Fakultas Sains dan Teknologi',
        password: hashedPassword,
      }
    });
    lecturersMap[l.name] = lecturer.id;
  }
  console.log(`✅ ${lecturersData.length} Profil Dosen Tersimpan`);

  // 5. Memasukkan Mata Kuliah (terhubung ke Lecturer)
  const coursesData = [
    { id: 'cl_logmat',          code: 'CL01', name: 'Logika Matematika',                   lecturerId: lecturersMap['Dr. Mivan Ariful Fathoni, M.Si'] },
    { id: 'cl_adpl',            code: 'CL02', name: 'Analisis Dan Desain Perangkat Lunak', lecturerId: lecturersMap['Muhammad Jauhar Fikri, S.Kom., M.Kom'] },
    { id: 'cl_mikrokontroller', code: 'CL03', name: 'Pemrograman Mikrokontroller',         lecturerId: lecturersMap['Guruh Putro Digantoro, S.Kom., M.Kom'] },
    { id: 'cl_mobile',          code: 'CL04', name: 'Pemrograman Berbasis Mobile',         lecturerId: lecturersMap['Zakki Alawi, S.Kom., MM'] },
    { id: 'cl_imk',             code: 'CL05', name: 'Interaksi Manusia & Komputer',        lecturerId: lecturersMap['Dwi Issadari Hastuti, S.Pd., S.Kom., M.Kom'] },
    { id: 'cl_iot',             code: 'CL06', name: 'Internet Of Things',                  lecturerId: lecturersMap['Mula Agung Barata, S.ST., M.Kom'] },
    { id: 'cl_komparsis',       code: 'CL07', name: 'Komputasi Paralel Dan Terdistribusi', lecturerId: lecturersMap['Afnil Efan Pajri, S.Kom., M.I.Kom'] },
  ];

  const courses = [];
  for (const c of coursesData) {
    const course = await prisma.course.upsert({
      where: { code: c.code },
      update: { name: c.name, lecturerId: c.lecturerId },
      create: c,
    });
    courses.push(course);
  }
  console.log(`✅ ${courses.length} Mata Kuliah Tersimpan`);

  // 6. Enrollment — Mahasiswa mengambil semua MK
  await prisma.enrollment.deleteMany({ where: { studentId: student.id } });
  await prisma.enrollment.createMany({
    data: courses.map(c => ({
      studentId: student.id,
      courseId: c.id,
    })),
  });
  console.log(`✅ Enrollment: ${student.name} → ${courses.length} mata kuliah`);

  // 7. Jadwal Pelajaran (sesuai mock_data.dart)
  await prisma.schedule.deleteMany();
  await prisma.schedule.createMany({
    data: [
      // Senin
      { dayOfWeek: 'Senin', startTime: '09:45', endTime: '11:00', room: 'FST H3', courseId: courses[0].id },
      { dayOfWeek: 'Senin', startTime: '11:30', endTime: '14:00', room: 'FST H6', courseId: courses[1].id },
      { dayOfWeek: 'Senin', startTime: '14:00', endTime: '15:30', room: 'FST H5', courseId: courses[2].id },
      // Selasa
      { dayOfWeek: 'Selasa', startTime: '10:00', endTime: '11:30', room: 'FST H8', courseId: courses[3].id },
      { dayOfWeek: 'Selasa', startTime: '11:30', endTime: '14:00', room: 'FST H6', courseId: courses[4].id },
      // Kamis
      { dayOfWeek: 'Kamis',  startTime: '08:30', endTime: '10:00', room: 'FST H8', courseId: courses[5].id },
      { dayOfWeek: 'Kamis',  startTime: '10:00', endTime: '11:30', room: 'FST H8', courseId: courses[6].id },
    ],
  });
  console.log(`✅ Jadwal Mingguan Tersimpan (7 slot)`);

  // 8. Sample Attendance Records (Pertemuan 1-8, beberapa absen/tidak hadir)
  await prisma.attendance.deleteMany({ where: { studentId: student.id } });
  const attendanceData = [];

  // Definisikan pola kehadiran per mata kuliah (true = hadir, false = tidak hadir/absen)
  const attendancePatterns = {
    0: [true, true, true, false, true, true, false, true],      // MK 1: 6 hadir, 2 absen
    1: [true, true, true, true, true, false, true, true],       // MK 2: 7 hadir, 1 absen
    2: [true, false, true, true, true, true, false, false],     // MK 3: 5 hadir, 3 absen
    3: [true, true, true, true, true, true, true, true],        // MK 4: 8 hadir (sempurna)
    4: [true, true, false, true, true, true, true, true],       // MK 5: 7 hadir, 1 absen
    5: [true, true, true, true, false, true, true, true],       // MK 6: 7 hadir, 1 absen
    6: [true, true, true, true, true, true, false, true],       // MK 7: 7 hadir, 1 absen
  };

  for (let ci = 0; ci < courses.length; ci++) {
    const pattern = attendancePatterns[ci] || Array(8).fill(true);
    for (let meeting = 1; meeting <= 8; meeting++) {
      if (pattern[meeting - 1]) {
        const date = new Date(2026, 1, 2 + (meeting - 1) * 7); // weekly
        attendanceData.push({
          status: 'present',
          meetingCount: meeting,
          studentId: student.id,
          courseId: courses[ci].id,
          date,
        });
      }
      // Jika false (tidak hadir), tidak ada record → backend akan mendeteksi sebagai absent
    }
  }
  await prisma.attendance.createMany({ data: attendanceData });
  const absentCount = courses.length * 8 - attendanceData.length;
  console.log(`✅ Sample Attendance: ${attendanceData.length} hadir + ${absentCount} absen (8 pertemuan × 7 MK)`);

  console.log('🌲 Seeding database selesai seluruhnya!');
}

main()
  .catch((e) => {
    console.error('❌ Gagal melakukan seeding:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
