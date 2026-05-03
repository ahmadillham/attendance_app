const prisma = require('../lib/prisma');

const getSchedules = async (req, res) => {
    try {
        const { dayOfWeek, date } = req.query;
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

        // Use client date for mock time support, fallback to server time
        const baseDate = date ? new Date(date) : new Date();
        const startOfDay = new Date(baseDate);
        startOfDay.setHours(0, 0, 0, 0);
        const endOfDay = new Date(baseDate);
        endOfDay.setHours(23, 59, 59, 999);

        const todaysAttendances = await prisma.attendance.findMany({
            where: {
                studentId,
                date: { gte: startOfDay, lte: endOfDay }
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
