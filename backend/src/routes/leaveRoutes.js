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

        const { reason, description, date } = req.body;
        const studentId = req.user.id;
        const leaveDate = new Date(date);

        // ── Time cutoff: leave requests for today must be submitted before all classes start ──
        const dayNames = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
        const leaveDayName = dayNames[leaveDate.getDay()];
        const now = new Date();

        // Check if the leave date is today (same calendar day)
        const isToday = leaveDate.getFullYear() === now.getFullYear()
            && leaveDate.getMonth() === now.getMonth()
            && leaveDate.getDate() === now.getDate();

        // Look up the student's enrolled courses that have schedules on this day
        const enrollments = await prisma.enrollment.findMany({
            where: { studentId },
            select: { courseId: true },
        });
        const courseIds = enrollments.map(e => e.courseId);

        const schedules = await prisma.schedule.findMany({
            where: {
                courseId: { in: courseIds },
                dayOfWeek: leaveDayName,
            },
        });

        if (schedules.length === 0) {
            return res.status(403).json({
                message: `Tidak ada jadwal kuliah pada hari ${leaveDayName}. Pengajuan izin ditolak.`,
            });
        }

        if (isToday) {
            const nowMinutes = now.getHours() * 60 + now.getMinutes();
            // Check if at least one class hasn't started yet
            const hasUpcoming = schedules.some(s => {
                const [h, m] = s.startTime.split(':').map(Number);
                return (h * 60 + m) > nowMinutes;
            });
            if (!hasUpcoming) {
                return res.status(403).json({
                    message: 'Semua kelas hari ini sudah dimulai. Pengajuan izin tidak dapat dilakukan setelah jam mulai kelas.',
                });
            }
        }

        // Check if user attached a document
        let evidenceUrl = null;
        if (req.file) {
            evidenceUrl = `/uploads/documents/${req.file.filename}`;
        }

        const leaveRequest = await prisma.leaveRequest.create({
            data: {
                reason,
                description,
                evidenceUrl,
                date: leaveDate,
                studentId
            }
        });
        res.status(201).json(leaveRequest);
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
            orderBy: { createdAt: 'desc' }
        });
        res.json(leaveRequests);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

module.exports = router;
