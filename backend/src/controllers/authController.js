// CHANGE-2026-09-07: Created Authentication Controller for user login and JWT token generation.

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { query } = require('../db/index');
const { sendSuccess, sendError } = require('../utils/response');

/**
 * POST /api/auth/login
 * Authenticates user credentials and returns JWT token.
 */
async function login(req, res, next) {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return sendError(res, 'Username/Email and Password are required.', [], 400);
    }

    const trimmedUser = username.toString().trim();
    const inputPass = password.toString();

    // Query user by username or email
    const users = await query(
      'SELECT id, username, email, password_hash, full_name, role, is_active FROM users WHERE username = ? OR email = ?',
      [trimmedUser, trimmedUser]
    );

    if (users.length === 0) {
      return sendError(res, 'Invalid username or password.', [], 401);
    }

    const user = users[0];

    // Check account active status
    if (user.is_active !== 1) {
      return sendError(res, 'Account is inactive. Please contact system administrator.', [], 403);
    }

    // Compare password hash
    const isMatch = await bcrypt.compare(inputPass, user.password_hash);
    if (!isMatch) {
      return sendError(res, 'Invalid username or password.', [], 401);
    }

    // Update last_login_at timestamp
    await query('UPDATE users SET last_login_at = NOW() WHERE id = ?', [user.id]);

    // Construct JWT Token Payload
    const userPayload = {
      id: user.id,
      username: user.username,
      email: user.email,
      full_name: user.full_name,
      role: user.role
    };

    const jwtSecret = process.env.JWT_SECRET || 'supersecret_printout_billing_jwt_key_2026';
    const token = jwt.sign(userPayload, jwtSecret, { expiresIn: '24h' });

    return sendSuccess(
      res,
      {
        token,
        user: userPayload
      },
      'Login successful'
    );
  } catch (err) { next(err); }
}

/**
 * GET /api/auth/me
 * Retrieves current authenticated user details.
 */
async function getMe(req, res, next) {
  try {
    if (!req.user || !req.user.id) {
      return sendError(res, 'Unauthenticated', [], 401);
    }

    const users = await query(
      'SELECT id, username, email, full_name, role, is_active, last_login_at, created_at FROM users WHERE id = ?',
      [req.user.id]
    );

    if (users.length === 0) {
      return sendError(res, 'User not found', [], 404);
    }

    return sendSuccess(res, users[0], 'User profile retrieved successfully');
  } catch (err) { next(err); }
}

module.exports = {
  login,
  getMe
};
