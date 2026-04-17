// Lecturer-only middleware — must be used AFTER authMiddleware
module.exports = function (req, res, next) {
    if (!req.user || req.user.role !== 'LECTURER') {
        return res.status(403).json({ message: 'Akses ditolak: hanya untuk dosen' });
    }
    next();
};
