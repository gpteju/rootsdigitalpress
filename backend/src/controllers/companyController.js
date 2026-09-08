// CHANGE-2026-09-07: Created Company Master controller for managing company profile.

const { query } = require('../db/index');
const { sendSuccess, sendError } = require('../utils/response');

/**
 * GET /api/company
 * Retrieves the primary company profile.
 */
async function getCompany(req, res, next) {
  try {
    const rows = await query('SELECT * FROM companies ORDER BY id ASC LIMIT 1');
    if (rows.length === 0) {
      return sendSuccess(res, null, 'Company profile has not been configured yet');
    }
    return sendSuccess(res, rows[0], 'Company profile retrieved successfully');
  } catch (err) {
    next(err);
  }
}

/**
 * POST /api/company or PUT /api/company
 * Creates or updates the company profile.
 */
async function saveCompany(req, res, next) {
  try {
    const {
      company_name,
      address,
      city,
      state,
      state_code,
      gstin,
      phone,
      email,
      invoice_prefix,
      estimate_prefix,
      estimate_current_number
    } = req.body;

    if (!company_name || !address || !city || !state || !state_code || !phone || !email) {
      return sendError(res, 'Missing required company fields', [
        'company_name, address, city, state, state_code, phone, email are required.'
      ]);
    }

    const existing = await query('SELECT id FROM companies ORDER BY id ASC LIMIT 1');

    if (existing.length > 0) {
      const companyId = existing[0].id;
      await query(
        `UPDATE companies SET 
          company_name = ?, address = ?, city = ?, state = ?, state_code = ?, 
          gstin = ?, phone = ?, email = ?, invoice_prefix = ?, 
          estimate_prefix = ?, estimate_current_number = ? 
        WHERE id = ?`,
        [company_name, address, city, state, state_code, gstin || null, phone, email, invoice_prefix || 'INV-', estimate_prefix || 'JOB-', parseInt(estimate_current_number || 0, 10), companyId]
      );
      const updated = await query('SELECT * FROM companies WHERE id = ?', [companyId]);
      return sendSuccess(res, updated[0], 'Company profile updated successfully');
    } else {
      const result = await query(
        `INSERT INTO companies 
          (company_name, address, city, state, state_code, gstin, phone, email, invoice_prefix, estimate_prefix, estimate_current_number) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [company_name, address, city, state, state_code, gstin || null, phone, email, invoice_prefix || 'INV-', estimate_prefix || 'JOB-', parseInt(estimate_current_number || 0, 10)]
      );
      const created = await query('SELECT * FROM companies WHERE id = ?', [result.insertId]);
      return sendSuccess(res, created[0], 'Company profile created successfully', 201);
    }
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getCompany,
  saveCompany
};
