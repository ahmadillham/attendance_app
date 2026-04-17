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
  const lecturer = await prisma.lecturer.upsert({
    where: { lecturerId: '198501012020' },
    update: {
      password: hashedPassword,
    },
    create: {
      lecturerId: '198501012020',
      name: 'Dr. Budi Santoso, M.Kom.',
      email: 'budi.santoso@unuha.ac.id',
      phone: '0813-3000-1234',
      department: 'Teknik Informatika',
      faculty: 'Fakultas Sains dan Teknologi',
      password: hashedPassword,
    }
  });

  console.log(`✅ Profil Dosen: ${lecturer.name} (NIP: ${lecturer.lecturerId}, Sandi: Password123)`);

  // 5. Memasukkan Mata Kuliah (terhubung ke Lecturer)
  const coursesData = [
    { id: 'cl_logmat',          code: 'CL01', name: 'Logika Matematika',                   lecturerId: lecturer.id },
    { id: 'cl_adpl',            code: 'CL02', name: 'Analisis Dan Desain Perangkat Lunak', lecturerId: lecturer.id },
    { id: 'cl_mikrokontroller', code: 'CL03', name: 'Pemrograman Mikrokontroller',         lecturerId: lecturer.id },
    { id: 'cl_mobile',          code: 'CL04', name: 'Pemrograman Berbasis Mobile',         lecturerId: lecturer.id },
    { id: 'cl_imk',             code: 'CL05', name: 'Interaksi Manusia & Komputer',        lecturerId: lecturer.id },
    { id: 'cl_iot',             code: 'CL06', name: 'Internet Of Things',                  lecturerId: lecturer.id },
    { id: 'cl_komparsis',       code: 'CL07', name: 'Komputasi Paralel Dan Terdistribusi', lecturerId: lecturer.id },
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
  console.log(`✅ ${courses.length} Mata Kuliah Tersimpan (diajar oleh ${lecturer.name})`);

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

  // 8. Sample Attendance Records (Pertemuan 1-6 untuk semua MK)
  await prisma.attendance.deleteMany({ where: { studentId: student.id } });
  const attendanceData = [];
  for (const course of courses) {
    for (let meeting = 1; meeting <= 6; meeting++) {
      const date = new Date(2026, 1, 2 + (meeting - 1) * 7); // weekly
      attendanceData.push({
        status: 'present',
        meetingCount: meeting,
        studentId: student.id,
        courseId: course.id,
        date,
      });
    }
  }
  await prisma.attendance.createMany({ data: attendanceData });
  console.log(`✅ Sample Attendance: ${attendanceData.length} records (6 pertemuan × 7 MK)`);

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
