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

        res.json(schedules);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

module.exports = { getSchedules };
