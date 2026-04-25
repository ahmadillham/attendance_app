const prisma = require('../lib/prisma');

const getSchedules = async (req, res) => {
    try {
        const { dayOfWeek } = req.query;
        const studentId = req.user.id;
        
        // Get courses this student is enrolled in
        const enrollments = await prisma.enrollment.findMany({
            where: { studentId },
            select: { courseId: true },
        });
        const enrolledCourseIds = enrollments.map(e => e.courseId);

        let filter = {
            courseId: { in: enrolledCourseIds },
        };
        if (dayOfWeek) {
            filter.dayOfWeek = dayOfWeek;
        }

        const schedules = await prisma.schedule.findMany({
            where: filter,
            include: { 
                course: {
                    include: { lecturer: true }
                }
            },
            orderBy: { startTime: 'asc' },
        });

        const twelveHoursAgo = new Date(Date.now() - 12 * 60 * 60 * 1000);
        const todaysAttendances = await prisma.attendance.findMany({
            where: {
                studentId,
                date: { gte: twelveHoursAgo }
            },
            select: { courseId: true }
        });
        const attendedCourseIds = new Set(todaysAttendances.map(a => a.courseId));

        const schedulesWithStatus = schedules.map(s => ({
            ...s,
            hasAttended: attendedCourseIds.has(s.courseId)
        }));

        res.json(schedulesWithStatus);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

module.exports = { getSchedules };
