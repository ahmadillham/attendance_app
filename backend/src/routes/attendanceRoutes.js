const express = require('express');
const router = express.Router();
const prisma = require('../lib/prisma');
const authMiddleware = require('../middlewares/authMiddleware');
const upload = require('../middlewares/uploadMiddleware');
const { verifyFace } = require('../lib/faceVerify');
const { attendanceValidation } = require('../validations/attendanceValidation');

// Haversine distance calculator
const haversineDistance = (lat1, lon1, lat2, lon2) => {
    const R = 6371e3; // Earth radius in meters
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
};

const CAMPUS_LAT = -7.167311;
const CAMPUS_LNG = 111.892951;
const ALLOWED_RADIUS = 200;

// POST /api/attendance
router.post('/', authMiddleware, upload.single('faceImage'), async (req, res) => {
    try {
        // Validate input fields (multer already parsed multipart, so req.body has strings)
        const validationData = {
            status: req.body.status,
            meetingCount: parseInt(req.body.meetingCount),
            courseId: req.body.courseId,
            latitude: parseFloat(req.body.latitude),
            longitude: parseFloat(req.body.longitude),
        };
        const { error } = attendanceValidation(validationData);
        if (error) return res.status(400).json({ message: error.details[0].message });

        const { status, meetingCount, courseId, latitude, longitude } = validationData;
        const studentId = req.user.id;

        // Security 1: Biometric Face Validation
        if (!req.file) {
            return res.status(400).json({ message: 'Akses ditolak: Foto wajah (FaceID) wajib dilampirkan untuk verifikasi.' });
        }

        // Fetch student's stored face descriptor for comparison
        const student = await prisma.student.findUnique({
            where: { id: studentId },
            select: { faceDescriptor: true },
        });

        if (!student || !student.faceDescriptor) {
            return res.status(400).json({ message: 'Akses ditolak: Data biometrik wajah belum terdaftar di sistem.' });
        }

        // NOTE: In a real system, you'd extract a 128D descriptor from req.file using
        // a face-recognition model (face-api.js / Python microservice / TensorFlow).
        // For now, we compare the stored descriptor against itself (always passes)
        // to demonstrate the cosine similarity pipeline.
        const storedDescriptor = student.faceDescriptor;
        const incomingDescriptor = storedDescriptor; // TODO: Replace with real extraction

        const faceResult = verifyFace(storedDescriptor, incomingDescriptor);
        if (!faceResult.matched) {
            return res.status(400).json({
                message: `Akses ditolak: Wajah tidak cocok (similarity: ${faceResult.similarity}). Coba lagi dengan pencahayaan lebih baik.`,
            });
        }

        // Security 2: Backend Geofencing Validation
        const distance = haversineDistance(latitude, longitude, CAMPUS_LAT, CAMPUS_LNG);
        if (distance > ALLOWED_RADIUS) {
            return res.status(403).json({ message: `Akses ditolak: Anda berada ${(distance).toFixed(1)} meter dari batas kampus. Radius maksimal ${ALLOWED_RADIUS}m.` });
        }

        // Security 3: Check for duplicate attendance
        const existing = await prisma.attendance.findFirst({
            where: { studentId, courseId, meetingCount },
        });
        if (existing) {
            return res.status(409).json({ message: `Absensi pertemuan ke-${meetingCount} untuk mata kuliah ini sudah tercatat.` });
        }

        // Security 4: Enrollment validation — student must be enrolled in this course
        const enrollment = await prisma.enrollment.findUnique({
            where: { studentId_courseId: { studentId, courseId } },
        });
        if (!enrollment) {
            return res.status(403).json({ message: 'Akses ditolak: Anda tidak terdaftar di mata kuliah ini.' });
        }

        const attendance = await prisma.attendance.create({
            data: {
                status,
                meetingCount,
                studentId,
                courseId
            }
        });
        res.status(201).json(attendance);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// GET /api/attendance/history
router.get('/history', authMiddleware, async (req, res) => {
    try {
        const studentId = req.user.id;
        const history = await prisma.attendance.findMany({
            where: { studentId },
            include: { course: true },
            orderBy: { date: 'desc' }
        });
        res.json(history);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

module.exports = router;
