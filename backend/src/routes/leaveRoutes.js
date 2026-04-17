const express = require('express');
const router = express.Router();
const prisma = require('../lib/prisma');
const authMiddleware = require('../middlewares/authMiddleware');
const upload = require('../middlewares/uploadMiddleware');
const { leaveValidation } = require('../validations/attendanceValidation');

const fs = require('fs');

// POST /api/leave-requests — Submit a new leave request
router.post('/', authMiddleware, upload.single('document'), async (req, res) => {
    try {
        fs.appendFileSync('leave_log.txt', JSON.stringify(req.body) + '\n');
        // Validate input
        const { error } = leaveValidation({
            reason: req.body.reason,
            description: req.body.description,
            dateFrom: req.body.dateFrom,
            dateTo: req.body.dateTo,
        });
        if (error) {
            fs.appendFileSync('leave_log.txt', 'VALIDATION ERROR: ' + error.details[0].message + '\n');
            return res.status(400).json({ message: error.details[0].message });
        }

        const { reason, description, dateFrom, dateTo } = req.body;
        const studentId = req.user.id;
        
        // Cek jika user melampirkan dokumen
        let evidenceUrl = null;
        if (req.file) {
            evidenceUrl = `/uploads/documents/${req.file.filename}`;
        }

        const leaveRequest = await prisma.leaveRequest.create({
            data: {
                reason,
                description,
                evidenceUrl,
                dateFrom: new Date(dateFrom),
                dateTo: new Date(dateTo),
                studentId
            }
        });
        res.status(201).json(leaveRequest);
    } catch (err) {
        fs.appendFileSync('leave_log.txt', 'SERVER ERROR: ' + err.message + '\n');
        res.status(500).json({ message: err.message });
    }
});

// GET /api/leave-requests — Get student's leave request history
router.get('/', authMiddleware, async (req, res) => {
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
