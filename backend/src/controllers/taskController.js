const prisma = require('../lib/prisma');

// GET /api/tasks — List student's tasks
const getTasks = async (req, res) => {
    try {
        const studentId = req.user.id;
        const { completed } = req.query;

        let filter = { studentId };
        if (completed !== undefined) {
            filter.completed = completed === 'true';
        }

        const tasks = await prisma.task.findMany({
            where: filter,
            orderBy: [
                { completed: 'asc' },
                { deadline: 'asc' },
            ],
        });

        res.json(tasks);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

// POST /api/tasks — Create a new task
const createTask = async (req, res) => {
    try {
        const studentId = req.user.id;
        const { title, description, deadline, priority } = req.body;

        if (!title || !deadline) {
            return res.status(400).json({ message: 'Judul dan deadline wajib diisi.' });
        }

        const task = await prisma.task.create({
            data: {
                title,
                description: description || null,
                deadline: new Date(deadline),
                priority: priority || 'medium',
                studentId,
            },
        });

        res.status(201).json(task);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

// PUT /api/tasks/:id — Update a task
const updateTask = async (req, res) => {
    try {
        const studentId = req.user.id;
        const { id } = req.params;
        const { title, description, deadline, priority, completed } = req.body;

        // Verify ownership
        const existing = await prisma.task.findUnique({ where: { id } });
        if (!existing || existing.studentId !== studentId) {
            return res.status(404).json({ message: 'Tugas tidak ditemukan.' });
        }

        const updateData = {};
        if (title !== undefined) updateData.title = title;
        if (description !== undefined) updateData.description = description;
        if (deadline !== undefined) updateData.deadline = new Date(deadline);
        if (priority !== undefined) updateData.priority = priority;
        if (completed !== undefined) updateData.completed = completed;

        const task = await prisma.task.update({
            where: { id },
            data: updateData,
        });

        res.json(task);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

// DELETE /api/tasks/:id — Delete a task
const deleteTask = async (req, res) => {
    try {
        const studentId = req.user.id;
        const { id } = req.params;

        const existing = await prisma.task.findUnique({ where: { id } });
        if (!existing || existing.studentId !== studentId) {
            return res.status(404).json({ message: 'Tugas tidak ditemukan.' });
        }

        await prisma.task.delete({ where: { id } });
        res.json({ message: 'Tugas berhasil dihapus.' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

module.exports = { getTasks, createTask, updateTask, deleteTask };
