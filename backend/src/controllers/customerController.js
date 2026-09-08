// CHANGE-2026-09-07: Created Customer Master controller.

const { query } = require('../db/index');
const { sendSuccess, sendError } = require('../utils/response');

/**
 * GET /api/customers
 */
async function getAllCustomers(req, res, next) {
  try {
    const { active_only } = req.query;
    let sql = 'SELECT * FROM customers';
    const params = [];
    if (active_only === 'true') {
      sql += ' WHERE is_active = 1';
    }
    sql += ' ORDER BY customer_name ASC';
    const customers = await query(sql, params);
    return sendSuccess(res, customers, 'Customers fetched successfully');
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/customers/:id
 */
async function getCustomerById(req, res, next) {
  try {
    const { id } = req.params;
    const rows = await query('SELECT * FROM customers WHERE id = ?', [id]);
    if (rows.length === 0) {
      return sendError(res, 'Customer not found', [], 404);
    }

    // Compute outstanding financial summary from sales_bills
    const pendingSummary = await query(
      `SELECT 
        COALESCE(SUM(grand_total), 0) AS total_billed,
        COALESCE(SUM(paid_amount), 0) AS total_paid,
        COALESCE(SUM(balance_amount), 0) AS total_outstanding,
        COUNT(id) AS bill_count
       FROM sales_bills 
       WHERE customer_id = ? AND status != 'PAID'`,
      [id]
    );

    const customerData = {
      ...rows[0],
      outstanding_summary: pendingSummary[0]
    };

    return sendSuccess(res, customerData, 'Customer details fetched successfully');
  } catch (err) {
    next(err);
  }
}

/**
 * POST /api/customers
 */
async function createCustomer(req, res, next) {
  try {
    const {
      customer_name,
      address,
      city,
      state,
      state_code,
      gstin,
      phone,
      email,
      credit_limit,
      payment_terms,
      is_estimate
    } = req.body;

    if (!customer_name || !state || !state_code) {
      return sendError(res, 'Customer name, state, and state code are required', [
        'customer_name, state, state_code cannot be empty.'
      ]);
    }

    const result = await query(
      `INSERT INTO customers 
        (customer_name, address, city, state, state_code, gstin, phone, email, credit_limit, payment_terms, is_estimate, is_active) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)`,
      [
        customer_name,
        address || null,
        city || null,
        state,
        state_code,
        gstin || null,
        phone || null,
        email || null,
        credit_limit || 0.00,
        payment_terms || 30,
        is_estimate ? 1 : 0
      ]
    );

    const created = await query('SELECT * FROM customers WHERE id = ?', [result.insertId]);
    return sendSuccess(res, created[0], 'Customer created successfully', 201);
  } catch (err) {
    next(err);
  }
}

/**
 * PUT /api/customers/:id
 */
async function updateCustomer(req, res, next) {
  try {
    const { id } = req.params;
    const {
      customer_name,
      address,
      city,
      state,
      state_code,
      gstin,
      phone,
      email,
      credit_limit,
      payment_terms,
      is_active,
      is_estimate
    } = req.body;

    const existing = await query('SELECT id FROM customers WHERE id = ?', [id]);
    if (existing.length === 0) {
      return sendError(res, 'Customer not found', [], 404);
    }

    await query(
      `UPDATE customers SET 
        customer_name = ?, address = ?, city = ?, state = ?, state_code = ?, 
        gstin = ?, phone = ?, email = ?, credit_limit = ?, payment_terms = ?, is_estimate = ?, is_active = ? 
       WHERE id = ?`,
      [
        customer_name,
        address || null,
        city || null,
        state,
        state_code,
        gstin || null,
        phone || null,
        email || null,
        credit_limit || 0.00,
        payment_terms || 30,
        is_estimate ? 1 : 0,
        is_active !== undefined ? is_active : 1,
        id
      ]
    );

    const updated = await query('SELECT * FROM customers WHERE id = ?', [id]);
    return sendSuccess(res, updated[0], 'Customer updated successfully');
  } catch (err) {
    next(err);
  }
}

/**
 * DELETE /api/customers/:id (Soft Deactivation)
 */
async function deleteCustomer(req, res, next) {
  try {
    const { id } = req.params;
    await query('UPDATE customers SET is_active = 0 WHERE id = ?', [id]);
    return sendSuccess(res, null, 'Customer deactivated successfully');
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getAllCustomers,
  getCustomerById,
  createCustomer,
  updateCustomer,
  deleteCustomer
};
