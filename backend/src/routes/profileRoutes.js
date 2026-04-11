const router = require('express').Router();
const { getProfile, changePassword } = require('../controllers/profileController');
const authMiddleware = require('../middlewares/authMiddleware');

router.get('/', authMiddleware, getProfile);
router.put('/password', authMiddleware, changePassword);

module.exports = router;
