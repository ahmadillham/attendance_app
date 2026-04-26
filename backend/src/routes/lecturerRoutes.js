const express = require('express');
const router = express.Router();
const prisma = require('../lib/prisma');
const bcrypt = require('bcryptjs');
const authMiddleware = require('../middlewares/authMiddleware');
const lecturerMiddleware = require('../middlewares/lecturerMiddleware');

// All routes require auth + lecturer role
router.use(authMiddleware);
router.use(lecturerMiddleware);

// ─── GET /api/lecturer/dashboard ─────────────────────────────────────
// Returns today's classes with attendance stats
router.get('/dashboard', async (req, res) => {
    try {
        const lecturerId = req.user.id;
        const dayNames = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
        const targetDate = req.query.date ? new Date(req.query.date) : new Date();
        const today = dayNames[targetDate.getDay()];

        // Get all courses taught by this lecturer
        const courses = await prisma.course.findMany({
            where: { lecturerId },
            include: {
                schedules: today === 'Minggu' ? false : { where: { dayOfWeek: today } },
                enrollments: { select: { id: true } },
            },
        });

        // Get today's attendance counts per course
        const startOfDay = new Date(targetDate);
        startOfDay.setHours(0, 0, 0, 0);
        const endOfDay = new Date(targetDate);
        endOfDay.setHours(23, 59, 59, 999);

        const todayCourses = [];
        for (const course of courses) {
            if (!course.schedules || course.schedules.length === 0) continue;

            const attendanceCounts = await prisma.attendance.groupBy({
                by: ['status'],
                where: {
                    courseId: course.id,
                    date: { gte: startOfDay, lte: endOfDay },
                },
                _count: { status: true },
            });

            const stats = { present: 0, absent: 0, leave: 0 };
            attendanceCounts.forEach(a => { stats[a.status] = a._count.status; });

            todayCourses.push({
                id: course.id,
                code: course.code,
                name: course.name,
                schedule: course.schedules[0],
                enrolledCount: course.enrollments.length,
                attendance: stats,
            });
        }

        // Count pending leave requests
        const pendingLeaveCount = await prisma.leaveRequest.count({
            where: {
                course: { lecturerId },
                status: 'PENDING',
            },
        });

        // Total stats
        const totalCourses = courses.length;
        const totalStudents = await prisma.enrollment.count({
            where: { course: { lecturerId } },
        });

        res.json({
            today,
            todayCourses,
            totalCourses,
            totalStudents,
            pendingLeaveCount,
        });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// ─── GET /api/lecturer/courses ───────────────────────────────────────
// Returns all courses taught by this lecturer
router.get('/courses', async (req, res) => {
    try {
        const courses = await prisma.course.findMany({
            where: { lecturerId: req.user.id },
            include: {
                schedules: true,
                enrollments: {
                    include: {
                        student: { select: { id: true, studentId: true, name: true } },
                    },
                },
                _count: { select: { attendances: true } },
            },
        });
        res.json(courses);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// ─── GET /api/lecturer/courses/:id/attendance ─────────────────────────
// Returns attendance recap for a specific course
router.get('/courses/:id/attendance', async (req, res) => {
    try {
        // Verify lecturer owns this course
        const course = await prisma.course.findFirst({
            where: { id: req.params.id, lecturerId: req.user.id },
        });
        if (!course) return res.status(403).json({ message: 'Akses ditolak' });

        // Get enrolled students
        const enrollments = await prisma.enrollment.findMany({
            where: { courseId: course.id },
            include: {
                student: { select: { id: true, studentId: true, name: true } },
            },
        });

        // Get all attendance records for this course
        const attendances = await prisma.attendance.findMany({
            where: { courseId: course.id },
            orderBy: [{ meetingCount: 'asc' }, { student: { name: 'asc' } }],
            include: {
                student: { select: { id: true, studentId: true, name: true } },
            },
        });

        // Get max meeting count
        const maxMeeting = attendances.length > 0
            ? Math.max(...attendances.map(a => a.meetingCount))
            : 0;

        res.json({ course, enrollments, attendances, maxMeeting });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// ─── PUT /api/lecturer/attendance/:id ────────────────────────────────
// Edit a student's attendance status
router.put('/attendance/:id', async (req, res) => {
    try {
        const { status } = req.body;
        if (!['present', 'absent', 'leave'].includes(status)) {
            return res.status(400).json({ message: 'Status tidak valid. Gunakan: present, absent, leave' });
        }

        // Verify the attendance belongs to a course this lecturer teaches
        const attendance = await prisma.attendance.findUnique({
            where: { id: req.params.id },
            include: { course: { select: { lecturerId: true } } },
        });
        if (!attendance) return res.status(404).json({ message: 'Data absensi tidak ditemukan' });
        if (attendance.course.lecturerId !== req.user.id) {
            return res.status(403).json({ message: 'Akses ditolak' });
        }

        const updated = await prisma.attendance.update({
            where: { id: req.params.id },
            data: { status },
        });

        res.json(updated);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// ─── GET /api/lecturer/leave-requests ────────────────────────────────
// Returns leave requests from students in lecturer's courses
router.get('/leave-requests', async (req, res) => {
    try {
        const leaveRequests = await prisma.leaveRequest.findMany({
            where: {
                course: { lecturerId: req.user.id },
            },
            include: {
                student: { select: { id: true, studentId: true, name: true, department: true } },
                course: { select: { name: true, code: true } },
                reviewedBy: { select: { name: true } },
            },
            orderBy: { createdAt: 'desc' },
        });

        res.json(leaveRequests);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// ─── PUT /api/lecturer/leave-requests/:id ────────────────────────────
// Approve or reject a leave request
router.put('/leave-requests/:id', async (req, res) => {
    try {
        const { status, reviewNote } = req.body;
        if (!['APPROVED', 'REJECTED'].includes(status)) {
            return res.status(400).json({ message: 'Status harus APPROVED atau REJECTED' });
        }

        // Verify the leave request exists and fetch student enrollments
        const existing = await prisma.leaveRequest.findUnique({ 
            where: { id: req.params.id },
            include: { course: true }
        });
        if (!existing) return res.status(404).json({ message: 'Pengajuan izin tidak ditemukan' });

        if (existing.course.lecturerId !== req.user.id) {
            return res.status(403).json({ message: 'Akses ditolak: Anda bukan pengampu mata kuliah ini.' });
        }

        const updated = await prisma.leaveRequest.update({
            where: { id: req.params.id },
            data: {
                status,
                reviewNote: reviewNote || null,
                reviewedById: req.user.id,
                reviewedAt: new Date(),
            },
            include: {
                student: { select: { studentId: true, name: true } },
            },
        });

        res.json(updated);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// ─── GET /api/lecturer/profile ───────────────────────────────────────
router.get('/profile', async (req, res) => {
    try {
        const lecturer = await prisma.lecturer.findUnique({
            where: { id: req.user.id },
            select: {
                id: true,
                lecturerId: true,
                name: true,
                email: true,
                phone: true,
                department: true,
                faculty: true,
                createdAt: true,
                _count: { select: { courses: true, reviewedLeaves: true } },
            },
        });

        if (!lecturer) return res.status(404).json({ message: 'Dosen tidak ditemukan' });
        res.json(lecturer);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// ─── PUT /api/lecturer/profile/password ──────────────────────────────
router.put('/profile/password', async (req, res) => {
    try {
        const { oldPassword, newPassword } = req.body;
        if (!oldPassword || !newPassword) {
            return res.status(400).json({ message: 'Password lama dan baru harus diisi.' });
        }
        if (newPassword.length < 6) {
            return res.status(400).json({ message: 'Password baru minimal 6 karakter.' });
        }

        const lecturer = await prisma.lecturer.findUnique({ where: { id: req.user.id } });
        if (!lecturer) return res.status(404).json({ message: 'Dosen tidak ditemukan' });

        const validPass = await bcrypt.compare(oldPassword, lecturer.password);
        if (!validPass) return res.status(400).json({ message: 'Password lama tidak sesuai.' });

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(newPassword, salt);

        await prisma.lecturer.update({
            where: { id: req.user.id },
            data: { password: hashedPassword },
        });

        res.json({ message: 'Password berhasil diubah.' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

module.exports = router;
