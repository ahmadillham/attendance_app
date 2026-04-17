const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');

// Load env vars
dotenv.config();

const app = express();

// Middlewares
app.use(cors());
app.use(express.json());

// Global logging middleware
app.use((req, res, next) => {
    console.log(`[REQ] ${req.method} ${req.url}`);
    next();
});

app.use('/uploads', express.static('uploads'));

// Routes
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/schedules', require('./routes/scheduleRoutes'));
app.use('/api/attendance', require('./routes/attendanceRoutes'));
app.use('/api/leave-requests', require('./routes/leaveRoutes'));
app.use('/api/profile', require('./routes/profileRoutes'));
app.use('/api/face', require('./routes/faceRoutes'));

app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', message: 'Absensi Backend API is running' });
});

// Global error handler (must be after all routes)
app.use(require('./middlewares/errorHandler'));

// Startup validation
if (!process.env.TOKEN_SECRET) {
    console.error('❌ FATAL: TOKEN_SECRET environment variable is not set!');
    process.exit(1);
}

// Start Server
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', async () => {
    console.log(`Server running on port ${PORT}`);

    // Load face recognition models in background (non-blocking)
    try {
        const { initFaceApi } = require('./lib/faceDescriptor');
        await initFaceApi();
    } catch (err) {
        console.warn(`⚠️  Face recognition unavailable: ${err.message}`);
    }
});
