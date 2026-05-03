const router = require("express").Router();
const { getSchedules } = require("../controllers/scheduleController");
const authMiddleware = require("../middlewares/authMiddleware");
const studentMiddleware = require("../middlewares/studentMiddleware");

router.get("/", authMiddleware, studentMiddleware, getSchedules);

module.exports = router;
