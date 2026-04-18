const prisma = require('../lib/prisma');
const bcrypt = require('bcryptjs');

// GET /api/profile — Retrieve signed-in student's profile
const getProfile = async (req, res) => {
    try {
        const studentId = req.user.id;
        const student = await prisma.student.findUnique({
            where: { id: studentId },
            select: {
                id: true,
                studentId: true,
                name: true,
                email: true,
                phone: true,
                department: true,
                faculty: true,
                semester: true,
                createdAt: true,
                updatedAt: true,
                _count: {
                    select: {
                        attendances: true,
                        leaveRequests: true,
                    }
                }
            }
        });

        if (!student) {
            return res.status(404).json({ message: 'Student not found' });
        }

        // Calculate attendance summary
        const attendances = await prisma.attendance.groupBy({
            by: ['status'],
            where: { studentId },
            _count: { status: true },
        });

        const summary = { present: 0, absent: 0, leave: 0, total: 0 };
        attendances.forEach(a => {
            summary[a.status] = a._count.status;
            summary.total += a._count.status;
        });

        // Include leave request outcomes in the summary:
        // APPROVED → counts as "leave" (izin)
        // REJECTED → counts as "absent" (absen)
        const leaveOutcomes = await prisma.leaveRequest.groupBy({
            by: ['status'],
            where: {
                studentId,
                status: { in: ['APPROVED', 'REJECTED'] },
            },
            _count: { status: true },
        });
        leaveOutcomes.forEach(lr => {
            if (lr.status === 'APPROVED') {
                summary.leave += lr._count.status;
                summary.total += lr._count.status;
            } else if (lr.status === 'REJECTED') {
                summary.absent += lr._count.status;
                summary.total += lr._count.status;
            }
        });

        // Fallback: if no records at all, avoid division by zero
        if (summary.total === 0) summary.total = 1;

        res.json({
            ...student,
            attendanceSummary: summary,
        });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

// PUT /api/profile/password — Change password
const changePassword = async (req, res) => {
    try {
        const studentId = req.user.id;
        const { oldPassword, newPassword } = req.body;

        if (!oldPassword || !newPassword) {
            return res.status(400).json({ message: 'Password lama dan baru harus diisi.' });
        }
        if (newPassword.length < 6) {
            return res.status(400).json({ message: 'Password baru minimal 6 karakter.' });
        }

        const student = await prisma.student.findUnique({ where: { id: studentId } });
        if (!student) return res.status(404).json({ message: 'Student not found' });

        const validPass = await bcrypt.compare(oldPassword, student.password);
        if (!validPass) return res.status(400).json({ message: 'Password lama tidak sesuai.' });

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(newPassword, salt);

        await prisma.student.update({
            where: { id: studentId },
            data: { password: hashedPassword },
        });

        res.json({ message: 'Password berhasil diubah.' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

module.exports = { getProfile, changePassword };
