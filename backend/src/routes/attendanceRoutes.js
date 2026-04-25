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

const CAMPUS_LAT = -7.160460;
const CAMPUS_LNG = 111.853767;
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
        // Window opens exactly at class start time, closes 15 minutes after class start
        const EARLY_OPEN_MINUTES = 0; // Exactly at start time
        const LATE_CLOSE_MINUTES = 15;
        const dayNames = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
        const clientNow = req.body.clientTime ? new Date(req.body.clientTime) : new Date();
        const todayDay = dayNames[clientNow.getDay()];

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
        const nowMinutes = clientNow.getHours() * 60 + clientNow.getMinutes();
        const classStartMinutes = startHour * 60 + startMin;
        const diffMinutes = nowMinutes - classStartMinutes;

        // diffMinutes < 0 means we're before class start, diffMinutes > 0 means after
        // Allow: from exactly at class start (diffMinutes >= 0) to 15 min after (diffMinutes <= 15)
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
            const lastAttendance = await prisma.attendance.findFirst({
                where: { studentId, courseId },
                orderBy: { meetingCount: 'desc' }
            });
            meetingCount = lastAttendance ? lastAttendance.meetingCount + 1 : 1;
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
                    message: 'Wajah tidak terdeteksi.'
                });
            }

            const faceResult = verifyFace(storedDescriptor, incomingDescriptor);
            if (!faceResult.matched) {
                return res.status(400).json({
                    message: 'Wajah tidak cocok dengan data sistem.',
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
                        message: 'Wajah tidak terdeteksi saat pengecekan gerakan.',
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
                        message: 'Gerakan wajah tidak terdeteksi.',
                    });
                }

                // Additionally verify that ALL liveness frames belong to the same person
                for (let i = 1; i < uploadedFiles.length; i++) {
                    const frameDescriptor = await extractDescriptor(uploadedFiles[i].path);
                    if (!frameDescriptor) continue; // skip undetected frames
                    const frameResult = verifyFace(storedDescriptor, frameDescriptor);
                    if (!frameResult.matched) {
                        return res.status(400).json({
                            message: 'Wajah tidak cocok saat pengecekan gerakan.',
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
            return res.status(403).json({ message: 'Anda berada di luar area kampus.' });
        }

        // Security 3: Check for duplicate attendance today (within last 12 hours)
        const twelveHoursAgo = new Date(Date.now() - 12 * 60 * 60 * 1000);
        const existingToday = await prisma.attendance.findFirst({
            where: { 
                studentId, 
                courseId,
                date: { gte: twelveHoursAgo }
            },
        });
        if (existingToday) {
            return res.status(409).json({ message: `Anda sudah absen untuk mata kuliah ini hari ini.` });
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

        // 1. Fetch attendance records
        const attendanceRecords = await prisma.attendance.findMany({
            where: { studentId },
            include: { 
                course: {
                    include: { lecturer: true }
                }
            },
            orderBy: [{ courseId: 'asc' }, { meetingCount: 'asc' }]
        });

        // 2. Fetch approved leave requests
        const approvedLeaves = await prisma.leaveRequest.findMany({
            where: { 
                studentId,
                status: 'APPROVED'
            },
            include: {
                course: {
                    include: { lecturer: true }
                }
            },
            orderBy: { date: 'desc' }
        });

        // 3. Fetch rejected leave requests (counts as absent)
        const rejectedLeaves = await prisma.leaveRequest.findMany({
            where: { 
                studentId,
                status: 'REJECTED'
            },
            include: {
                course: {
                    include: { lecturer: true }
                }
            },
            orderBy: { date: 'desc' }
        });

        // 4. Fetch enrolled courses
        const enrollments = await prisma.enrollment.findMany({
            where: { studentId },
            include: {
                course: {
                    include: { lecturer: true }
                }
            }
        });

        // 5. Build per-course data
        const courseData = {};

        // Initialize from enrollments
        for (const enrollment of enrollments) {
            courseData[enrollment.courseId] = {
                course: enrollment.course,
                presentMeetings: new Set(),
                leaveMeetings: new Set(),
                maxMeeting: 0,
                records: [],
            };
        }

        // Fill attendance records
        for (const record of attendanceRecords) {
            const cid = record.courseId;
            if (!courseData[cid]) {
                courseData[cid] = {
                    course: record.course,
                    presentMeetings: new Set(),
                    leaveMeetings: new Set(),
                    maxMeeting: 0,
                    records: [],
                };
            }
            courseData[cid].presentMeetings.add(record.meetingCount);
            if (record.meetingCount > courseData[cid].maxMeeting) {
                courseData[cid].maxMeeting = record.meetingCount;
            }
            courseData[cid].records.push(record);
        }

        // Fill approved leaves (status: 'leave')
        for (const leave of approvedLeaves) {
            const cid = leave.courseId;
            if (!courseData[cid]) continue;

            courseData[cid].maxMeeting += 1;
            const meetingNum = courseData[cid].maxMeeting;
            courseData[cid].leaveMeetings.add(meetingNum);

            courseData[cid].records.push({
                id: leave.id,
                status: 'leave',
                date: leave.date,
                meetingCount: meetingNum,
                faceVerified: false,
                studentId: leave.studentId,
                courseId: leave.courseId,
                course: leave.course,
                createdAt: leave.createdAt,
                updatedAt: leave.updatedAt,
            });
        }

        // Fill rejected leaves (counts as absent — student was not present and has no valid excuse)
        for (const leave of rejectedLeaves) {
            const cid = leave.courseId;
            if (!courseData[cid]) continue;

            courseData[cid].maxMeeting += 1;
            const meetingNum = courseData[cid].maxMeeting;

            courseData[cid].records.push({
                id: leave.id,
                status: 'absent',
                date: leave.date,
                meetingCount: meetingNum,
                faceVerified: false,
                studentId: leave.studentId,
                courseId: leave.courseId,
                course: leave.course,
                createdAt: leave.createdAt,
                updatedAt: leave.updatedAt,
            });
        }

        // 6. Calculate absent meetings from gaps in meetingCount
        for (const cid of Object.keys(courseData)) {
            const cd = courseData[cid];
            const allCoveredMeetings = new Set([...cd.presentMeetings, ...cd.leaveMeetings]);
            
            for (let m = 1; m <= cd.maxMeeting; m++) {
                if (!allCoveredMeetings.has(m)) {
                    // Check if this gap is already covered by a rejected leave record
                    const alreadyHasRecord = cd.records.some(r => r.meetingCount === m);
                    if (alreadyHasRecord) continue;

                    const firstRecord = cd.records.find(r => r.meetingCount === 1);
                    const baseDate = firstRecord ? new Date(firstRecord.date) : new Date();
                    const estimatedDate = new Date(baseDate);
                    estimatedDate.setDate(estimatedDate.getDate() + (m - 1) * 7);

                    cd.records.push({
                        id: `absent-${cid}-${m}`,
                        status: 'absent',
                        date: estimatedDate,
                        meetingCount: m,
                        faceVerified: false,
                        studentId: studentId,
                        courseId: cid,
                        course: cd.course,
                        createdAt: estimatedDate,
                        updatedAt: estimatedDate,
                    });
                }
            }
        }

        // 7. Merge all records and sort by date descending
        const combined = Object.values(courseData).flatMap(cd => cd.records);
        combined.sort((a, b) => new Date(b.date) - new Date(a.date));

        res.json(combined);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

module.exports = router;
