// CHANGE-2026-09-07: Created standard API Response helper utility.

/**
 * Sends a standardized success HTTP JSON response.
 * @param {Object} res - Express response object
 * @param {*} data - Data payload
 * @param {string} message - Success message
 * @param {number} statusCode - HTTP Status code (default 200)
 */
function sendSuccess(res, data = {}, message = 'Success', statusCode = 200) {
  return res.status(statusCode).json({
    success: true,
    message: message,
    data: data,
    errors: []
  });
}

/**
 * Sends a standardized error HTTP JSON response.
 * @param {Object} res - Express response object
 * @param {string} message - Error message summary
 * @param {Array} errors - Detailed list of validation/field errors
 * @param {number} statusCode - HTTP Status code (default 400)
 */
function sendError(res, message = 'An error occurred', errors = [], statusCode = 400) {
  return res.status(statusCode).json({
    success: false,
    message: message,
    data: null,
    errors: Array.isArray(errors) ? errors : [errors]
  });
}

module.exports = {
  sendSuccess,
  sendError
};
