const jwt = require('jsonwebtoken');

module.exports = function (req, res, next) {
    const token = req.header('Authorization');
    if (!token) return res.status(401).json({ message: 'Access Denied: No token provided' });

    try {
        if (!process.env.TOKEN_SECRET) {
            return res.status(500).json({ message: 'Server misconfiguration: TOKEN_SECRET is not set' });
        }
        const verified = jwt.verify(token.replace('Bearer ', ''), process.env.TOKEN_SECRET);
        req.user = verified;
        next();
    } catch (err) {
        res.status(400).json({ message: 'Invalid Token' });
    }
};
