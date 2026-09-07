// CHANGE-2026-09-07: Created Auth API router for login and session routes.

const express = require('express');
const router = express.Router();
const controller = require('../controllers/authController');
const { authenticateToken } = require('../middleware/authMiddleware');

router.post('/login', controller.login);
router.get('/me', authenticateToken, controller.getMe);

module.exports = router;
