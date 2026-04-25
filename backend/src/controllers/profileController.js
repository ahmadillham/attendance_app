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

        // Calculate attendance summary (synced with /attendance/history logic)
        // 1. Get all attendance records grouped by course
        const attendanceRecords = await prisma.attendance.findMany({
            where: { studentId },
            select: { courseId: true, meetingCount: true, status: true },
        });

        // 2. Get approved leave requests
        const approvedLeaves = await prisma.leaveRequest.findMany({
            where: { studentId, status: 'APPROVED' },
            select: { courseId: true },
        });

        // 3. Get rejected leave requests (counts as absent)
        const rejectedLeaves = await prisma.leaveRequest.findMany({
            where: { studentId, status: 'REJECTED' },
            select: { courseId: true },
        });

        // 4. Build per-course max meeting and present count
        const courseStats = {};
        for (const record of attendanceRecords) {
            const cid = record.courseId;
            if (!courseStats[cid]) courseStats[cid] = { maxMeeting: 0, presentMeetings: new Set() };
            courseStats[cid].presentMeetings.add(record.meetingCount);
            if (record.meetingCount > courseStats[cid].maxMeeting) {
                courseStats[cid].maxMeeting = record.meetingCount;
            }
        }

        // 5. Count leaves per course
        const leavesPerCourse = {};
        for (const leave of approvedLeaves) {
            leavesPerCourse[leave.courseId] = (leavesPerCourse[leave.courseId] || 0) + 1;
        }

        const rejectedPerCourse = {};
        for (const leave of rejectedLeaves) {
            rejectedPerCourse[leave.courseId] = (rejectedPerCourse[leave.courseId] || 0) + 1;
        }

        // 6. Calculate totals
        const summary = { present: 0, absent: 0, leave: 0, total: 0 };

        for (const cid of Object.keys(courseStats)) {
            const cs = courseStats[cid];
            const leaveCount = leavesPerCourse[cid] || 0;
            const rejectedCount = rejectedPerCourse[cid] || 0;
            const totalMeetings = cs.maxMeeting + leaveCount + rejectedCount;
            const presentCount = cs.presentMeetings.size;
            const absentCount = totalMeetings - presentCount - leaveCount;

            summary.present += presentCount;
            summary.leave += leaveCount;
            summary.absent += absentCount;
            summary.total += totalMeetings;
        }

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
