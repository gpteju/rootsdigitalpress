// CHANGE-2026-09-07: Created JWT Authentication Middleware for protecting backend REST endpoints.

const jwt = require('jsonwebtoken');
const { sendError } = require('../utils/response');

/**
 * Middleware validating Bearer JWT authentication tokens on protected routes.
 */
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.startsWith('Bearer ') ? authHeader.split(' ')[1] : null;

  if (!token) {
    return sendError(res, 'Authentication token required. Please log in.', [], 401);
  }

  const jwtSecret = process.env.JWT_SECRET || 'supersecret_printout_billing_jwt_key_2026';

  jwt.verify(token, jwtSecret, (err, user) => {
    if (err) {
      return sendError(res, 'Invalid or expired authentication token. Please log in again.', [], 403);
    }
    req.user = user;
    next();
  });
}

module.exports = {
  authenticateToken
};
