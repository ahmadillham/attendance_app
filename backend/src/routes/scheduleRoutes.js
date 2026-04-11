const router = require('express').Router();
const { getSchedules } = require('../controllers/scheduleController');
const authMiddleware = require('../middlewares/authMiddleware');

router.get('/', authMiddleware, getSchedules);

module.exports = router;
