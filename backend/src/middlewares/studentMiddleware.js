module.exports = function (req, res, next) {
    if (!req.user || req.user.role !== 'STUDENT') {
        return res.status(403).json({ message: 'Akses ditolak: hanya untuk mahasiswa' });
    }
    next();
};
