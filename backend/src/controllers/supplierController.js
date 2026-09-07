// CHANGE-2026-09-07: Created Supplier Master controller.

const { query } = require('../db/index');
const { sendSuccess, sendError } = require('../utils/response');

async function getAllSuppliers(req, res, next) {
  try {
    const { active_only } = req.query;
    let sql = 'SELECT * FROM suppliers';
    if (active_only === 'true') {
      sql += ' WHERE is_active = 1';
    }
    sql += ' ORDER BY supplier_name ASC';
    const suppliers = await query(sql);
    return sendSuccess(res, suppliers, 'Suppliers fetched successfully');
  } catch (err) {
    next(err);
  }
}

async function getSupplierById(req, res, next) {
  try {
    const { id } = req.params;
    const rows = await query('SELECT * FROM suppliers WHERE id = ?', [id]);
    if (rows.length === 0) {
      return sendError(res, 'Supplier not found', [], 404);
    }
    return sendSuccess(res, rows[0], 'Supplier details fetched successfully');
  } catch (err) {
    next(err);
  }
}

async function createSupplier(req, res, next) {
  try {
    const {
      supplier_name,
      address,
      city,
      state,
      state_code,
      gstin,
      phone,
      email,
      payment_terms
    } = req.body;

    if (!supplier_name || !state || !state_code) {
      return sendError(res, 'Supplier name, state, and state code are required');
    }

    const result = await query(
      `INSERT INTO suppliers 
        (supplier_name, address, city, state, state_code, gstin, phone, email, payment_terms, is_active) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1)`,
      [
        supplier_name,
        address || null,
        city || null,
        state,
        state_code,
        gstin || null,
        phone || null,
        email || null,
        payment_terms || 30
      ]
    );

    const created = await query('SELECT * FROM suppliers WHERE id = ?', [result.insertId]);
    return sendSuccess(res, created[0], 'Supplier created successfully', 201);
  } catch (err) {
    next(err);
  }
}

async function updateSupplier(req, res, next) {
  try {
    const { id } = req.params;
    const {
      supplier_name,
      address,
      city,
      state,
      state_code,
      gstin,
      phone,
      email,
      payment_terms,
      is_active
    } = req.body;

    const existing = await query('SELECT id FROM suppliers WHERE id = ?', [id]);
    if (existing.length === 0) {
      return sendError(res, 'Supplier not found', [], 404);
    }

    await query(
      `UPDATE suppliers SET 
        supplier_name = ?, address = ?, city = ?, state = ?, state_code = ?, 
        gstin = ?, phone = ?, email = ?, payment_terms = ?, is_active = ? 
       WHERE id = ?`,
      [
        supplier_name,
        address || null,
        city || null,
        state,
        state_code,
        gstin || null,
        phone || null,
        email || null,
        payment_terms || 30,
        is_active !== undefined ? is_active : 1,
        id
      ]
    );

    const updated = await query('SELECT * FROM suppliers WHERE id = ?', [id]);
    return sendSuccess(res, updated[0], 'Supplier updated successfully');
  } catch (err) {
    next(err);
  }
}

async function deleteSupplier(req, res, next) {
  try {
    const { id } = req.params;
    await query('UPDATE suppliers SET is_active = 0 WHERE id = ?', [id]);
    return sendSuccess(res, null, 'Supplier deactivated successfully');
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getAllSuppliers,
  getSupplierById,
  createSupplier,
  updateSupplier,
  deleteSupplier
};
