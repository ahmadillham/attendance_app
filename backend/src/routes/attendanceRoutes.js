const express = require('express');
const router = express.Router();
const fs = require('fs');
const prisma = require('../lib/prisma');
const authMiddleware = require('../middlewares/authMiddleware');
const studentMiddleware = require('../middlewares/studentMiddleware');
const upload = require('../middlewares/uploadMiddleware');
const { verifyFace } = require('../lib/faceVerify');
const { extractDescriptor, extractLandmarks, isAvailable: isFaceModelAvailable } = require('../lib/faceDescriptor');
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

// Minimum landmark movement (Euclidean pixel distance) required between
// the first and last liveness frames to prove the face physically moved.
const LIVENESS_MOVEMENT_THRESHOLD = 8;

/**
 * Calculate average Euclidean distance between two 68-point landmark arrays.
 * Each landmark is { x, y }. Returns the mean pixel displacement.
 */
function landmarkMovement(landmarksA, landmarksB) {
    if (!landmarksA || !landmarksB) return 0;
    const len = Math.min(landmarksA.length, landmarksB.length);
    let totalDist = 0;
    for (let i = 0; i < len; i++) {
        const dx = landmarksA[i].x - landmarksB[i].x;
        const dy = landmarksA[i].y - landmarksB[i].y;
        totalDist += Math.sqrt(dx * dx + dy * dy);
    }
    return totalDist / len;
}

/**
 * Safely delete an uploaded file (best-effort, non-blocking).
 */
function cleanupFile(filePath) {
    if (!filePath) return;
    fs.unlink(filePath, (err) => {
        if (err && err.code !== 'ENOENT') {
            console.warn(`⚠️  Failed to cleanup file ${filePath}: ${err.message}`);
        }
    });
}

/**
 * Safely delete an array of uploaded files.
 */
function cleanupFiles(files) {
    if (!files || !Array.isArray(files)) return;
    files.forEach(f => cleanupFile(f.path));
}

// POST /api/attendance
// Accepts multiple face images for liveness detection:
//   - faceImages[0]: primary face image (used for identity verification)
//   - faceImages[1..N]: liveness frames (used to detect physical face movement)
// Also still supports single 'faceImage' field for backward compatibility.
router.post('/', authMiddleware, studentMiddleware, upload.array('faceImages', 5), async (req, res) => {
    // Track all uploaded files for cleanup
    const uploadedFiles = req.files || [];
    // Backward compatibility: if client sent single 'faceImage' field via upload.single
    if (req.file) uploadedFiles.push(req.file);

    try {
        // Validate input fields (multer already parsed multipart, so req.body has strings)
        const validationData = {
            status: req.body.status,
            meetingCount: req.body.meetingCount ? parseInt(req.body.meetingCount) : undefined,
            courseId: req.body.courseId,
            latitude: parseFloat(req.body.latitude),
            longitude: parseFloat(req.body.longitude),
        };
        const { error } = attendanceValidation(validationData);
        if (error) return res.status(400).json({ message: error.details[0].message });

        const { status, courseId, latitude, longitude } = validationData;
        let { meetingCount } = validationData;
        const studentId = req.user.id;

        // Security 4: Enrollment validation — student must be enrolled in this course
        const enrollment = await prisma.enrollment.findUnique({
            where: { studentId_courseId: { studentId, courseId } },
        });
        if (!enrollment) {
            return res.status(403).json({ message: 'Akses ditolak: Anda tidak terdaftar di mata kuliah ini.' });
        }

        // Security 5: Time-window validation
        // Window opens 12 hours before class start, closes 15 minutes after class start
        const EARLY_OPEN_MINUTES = 12 * 60; // 12 hours = 720 minutes
        const LATE_CLOSE_MINUTES = 15;
        const dayNames = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
        const todayDay = dayNames[new Date().getDay()];

        const schedule = await prisma.schedule.findFirst({
            where: { courseId, dayOfWeek: todayDay },
        });
        if (!schedule) {
            return res.status(403).json({
                message: 'Tidak ada jadwal untuk mata kuliah ini hari ini.',
            });
        }

        // Parse schedule startTime (format "HH:mm") and compare with current time
        const [startHour, startMin] = schedule.startTime.split(':').map(Number);
        const now = new Date();
        const nowMinutes = now.getHours() * 60 + now.getMinutes();
        const classStartMinutes = startHour * 60 + startMin;
        const diffMinutes = nowMinutes - classStartMinutes;

        // diffMinutes < 0 means we're before class start, diffMinutes > 0 means after
        // Allow: from 720 min before (diffMinutes >= -720) to 15 min after (diffMinutes <= 15)
        if (diffMinutes < -EARLY_OPEN_MINUTES || diffMinutes > LATE_CLOSE_MINUTES) {
            const windowStartMin = classStartMinutes - EARLY_OPEN_MINUTES;
            const windowEndMin = classStartMinutes + LATE_CLOSE_MINUTES;
            const fmtTime = (m) => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
            return res.status(403).json({
                message: `Absensi hanya dapat dilakukan antara ${fmtTime(Math.max(0, windowStartMin))} – ${fmtTime(windowEndMin)}.`,
            });
        }

        // Auto-calculate meeting count if not provided
        if (!meetingCount) {
            const previousAttendances = await prisma.attendance.count({
                where: { studentId, courseId }
            });
            meetingCount = previousAttendances + 1;
        }

        // Security 1: Biometric Face Validation
        if (!uploadedFiles.length) {
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

        const storedDescriptor = student.faceDescriptor;
        let faceVerified = false;

        // Extract 128D descriptor from the uploaded face image
        if (isFaceModelAvailable()) {
            // ─── Identity Verification (primary frame) ────────────────────
            const primaryFile = uploadedFiles[0];
            const incomingDescriptor = await extractDescriptor(primaryFile.path);
            if (!incomingDescriptor) {
                return res.status(400).json({
                    message: 'Wajah tidak terdeteksi dalam foto. Pastikan wajah terlihat jelas dan pencahayaan cukup.'
                });
            }

            const faceResult = verifyFace(storedDescriptor, incomingDescriptor);
            if (!faceResult.matched) {
                return res.status(400).json({
                    message: `Akses ditolak: Wajah tidak cocok (similarity: ${faceResult.similarity}). Coba lagi dengan pencahayaan lebih baik.`,
                });
            }

            // ─── Liveness Detection (multi-frame challenge) ───────────────
            // Requires at least 2 frames to detect physical face movement.
            // If only 1 frame was sent, mark as identity-verified but not liveness-verified.
            if (uploadedFiles.length >= 2) {
                const firstLandmarks = await extractLandmarks(uploadedFiles[0].path);
                const lastLandmarks = await extractLandmarks(uploadedFiles[uploadedFiles.length - 1].path);

                if (!firstLandmarks || !lastLandmarks) {
                    return res.status(400).json({
                        message: 'Deteksi liveness gagal: Wajah tidak terdeteksi di salah satu frame. Pastikan wajah tetap terlihat selama verifikasi.',
                    });
                }

                const movement = landmarkMovement(firstLandmarks, lastLandmarks);
                console.log(JSON.stringify({
                    event: 'liveness_check',
                    movement: Math.round(movement * 100) / 100,
                    threshold: LIVENESS_MOVEMENT_THRESHOLD,
                    passed: movement >= LIVENESS_MOVEMENT_THRESHOLD,
                    frames: uploadedFiles.length,
                    studentId,
                    timestamp: new Date().toISOString(),
                }));

                if (movement < LIVENESS_MOVEMENT_THRESHOLD) {
                    return res.status(400).json({
                        message: 'Deteksi liveness gagal: Tidak terdeteksi gerakan wajah. Pastikan Anda mengikuti instruksi (kedipkan mata / tolehkan kepala).',
                    });
                }

                // Additionally verify that ALL liveness frames belong to the same person
                for (let i = 1; i < uploadedFiles.length; i++) {
                    const frameDescriptor = await extractDescriptor(uploadedFiles[i].path);
                    if (!frameDescriptor) continue; // skip undetected frames
                    const frameResult = verifyFace(storedDescriptor, frameDescriptor);
                    if (!frameResult.matched) {
                        return res.status(400).json({
                            message: `Deteksi liveness gagal: Wajah pada frame ${i + 1} tidak cocok dengan data biometrik Anda.`,
                        });
                    }
                }

                faceVerified = true; // Full verification: identity + liveness
            } else {
                // Single frame: identity verified but no liveness check
                faceVerified = true;
                console.warn(`⚠️  Attendance from student ${studentId}: identity verified but liveness NOT checked (single frame).`);
            }
        } else {
            // FLAG-AND-ALLOW MODE: Models not loaded, allow attendance but flag it
            // In production (NODE_ENV=production), reject instead
            if (process.env.NODE_ENV === 'production') {
                return res.status(503).json({
                    message: 'Layanan verifikasi wajah sedang tidak tersedia. Silakan coba lagi nanti atau hubungi administrator.',
                });
            }
            faceVerified = false;
            console.warn(`⚠️  Face verification UNAVAILABLE — attendance will be flagged as unverified (faceVerified=false) for student ${studentId}`);
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

        try {
            const attendance = await prisma.attendance.create({
                data: {
                    status,
                    meetingCount,
                    faceVerified,
                    studentId,
                    courseId
                }
            });
            res.status(201).json(attendance);
        } catch (createErr) {
            if (createErr.code === 'P2002') {
                return res.status(409).json({ message: `Konflik: Absensi pertemuan ke-${meetingCount} untuk mata kuliah ini sudah tercatat (mencegah duplikasi simultan).` });
            }
            throw createErr;
        }
    } catch (err) {
        res.status(500).json({ message: err.message });
    } finally {
        // Always cleanup uploaded face images — they're no longer needed
        // after descriptor extraction (descriptors are in-memory only)
        cleanupFiles(uploadedFiles);
    }
});

// GET /api/attendance/history
router.get('/history', authMiddleware, studentMiddleware, async (req, res) => {
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
