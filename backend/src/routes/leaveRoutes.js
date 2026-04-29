const express = require('express');
const router = express.Router();
const prisma = require('../lib/prisma');
const authMiddleware = require('../middlewares/authMiddleware');
const studentMiddleware = require('../middlewares/studentMiddleware');
const upload = require('../middlewares/uploadMiddleware');
const { leaveValidation } = require('../validations/attendanceValidation');

// POST /api/leave-requests — Submit a new leave request (single date)
router.post('/', authMiddleware, studentMiddleware, upload.single('document'), async (req, res) => {
    try {
        // Validate input
        const { error } = leaveValidation({
            reason: req.body.reason,
            description: req.body.description,
            date: req.body.date,
        });
        if (error) {
            return res.status(400).json({ message: error.details[0].message });
        }

        if (!req.body.courseIds) {
            return res.status(400).json({ message: "Pilih setidaknya satu mata kuliah." });
        }

        const { reason, description, date } = req.body;
        const studentId = req.user.id;
        const leaveDate = new Date(date);
        
        let courseIds = [];
        try {
            // parse JSON if array, otherwise split by comma
            courseIds = JSON.parse(req.body.courseIds);
        } catch (e) {
            courseIds = req.body.courseIds.split(',').map(s => s.trim()).filter(Boolean);
        }

        if (courseIds.length === 0) {
            return res.status(400).json({ message: "Mata kuliah tidak valid." });
        }

        const dayNames = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
        const leaveDayName = dayNames[leaveDate.getDay()];

        // Use clientTime for dev/testing (mock time support), fallback to server time
        // TODO: In production, always use server time: new Date()
        const now = req.body.clientTime ? new Date(req.body.clientTime) : new Date();

        const isToday = leaveDate.getFullYear() === now.getFullYear()
            && leaveDate.getMonth() === now.getMonth()
            && leaveDate.getDate() === now.getDate();

        // Validate schedules for the selected courses
        const schedules = await prisma.schedule.findMany({
            where: {
                courseId: { in: courseIds },
                dayOfWeek: leaveDayName,
            },
        });

        if (schedules.length !== courseIds.length) {
             return res.status(403).json({
                 message: `Beberapa mata kuliah yang dipilih tidak ada jadwal di hari ${leaveDayName}.`,
             });
        }

        if (isToday) {
            const nowMinutes = now.getHours() * 60 + now.getMinutes();
            for (const courseId of courseIds) {
                const schedule = schedules.find(s => s.courseId === courseId);
                const [h, m] = schedule.startTime.split(':').map(Number);
                const classStartMinutes = h * 60 + m;
                
                if (nowMinutes >= classStartMinutes) {
                    const fmtTime = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
                    return res.status(403).json({
                        message: `Batas pengajuan izin untuk mata kuliah ini adalah pukul ${fmtTime}. Pengajuan izin tidak dapat dilakukan setelah kelas dimulai.`,
                    });
                }
            }
        }

        let evidenceUrl = null;
        if (req.file) {
            evidenceUrl = `/uploads/documents/${req.file.filename}`;
        }

        // Check for duplicate leave requests (same student, same course, same date)
        const startOfDay = new Date(leaveDate);
        startOfDay.setHours(0, 0, 0, 0);
        const endOfDay = new Date(leaveDate);
        endOfDay.setHours(23, 59, 59, 999);

        const existingLeaves = await prisma.leaveRequest.findMany({
            where: {
                studentId,
                courseId: { in: courseIds },
                date: { gte: startOfDay, lte: endOfDay },
            },
            include: { course: true },
        });

        if (existingLeaves.length > 0) {
            const courseNames = existingLeaves.map(l => l.course.name).join(', ');
            return res.status(400).json({
                message: `Anda sudah mengajukan izin untuk: ${courseNames} pada tanggal tersebut.`,
            });
        }

        const leaveRequestsData = courseIds.map(courseId => ({
            reason,
            description,
            evidenceUrl,
            date: leaveDate,
            studentId,
            courseId,
        }));

        await prisma.leaveRequest.createMany({
            data: leaveRequestsData
        });

        res.status(201).json({ message: "Pengajuan izin berhasil dibuat untuk mata kuliah terpilih." });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// GET /api/leave-requests — Get student's leave request history
router.get('/', authMiddleware, studentMiddleware, async (req, res) => {
    try {
        const studentId = req.user.id;
        const leaveRequests = await prisma.leaveRequest.findMany({
            where: { studentId },
            include: { course: { select: { name: true, code: true } } },
            orderBy: { createdAt: 'desc' }
        });
        res.json(leaveRequests);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

module.exports = router;
