const router = require("express").Router();
const {
  getProfile,
  changePassword,
} = require("../controllers/profileController");
const authMiddleware = require("../middlewares/authMiddleware");
const studentMiddleware = require("../middlewares/studentMiddleware");

router.get("/", authMiddleware, studentMiddleware, getProfile);
router.put("/password", authMiddleware, studentMiddleware, changePassword);

module.exports = router;
