// CHANGE-2026-09-07: Created Rate Master controller for managing configurable pricing rates.

const { query } = require('../db/index');
const { sendSuccess, sendError } = require('../utils/response');

async function getRates(req, res, next) {
  try {
    const sql = `
      SELECT 
        r.*,
        p.paper_name,
        pt.name AS printout_type_name
      FROM rates r
      JOIN papers p ON r.paper_id = p.id
      JOIN printout_types pt ON r.printout_type_id = pt.id
      ORDER BY p.paper_name ASC, pt.name ASC
    `;
    const rows = await query(sql);
    return sendSuccess(res, rows, 'Rates fetched successfully');
  } catch (err) { next(err); }
}

async function lookupRate(req, res, next) {
  try {
    const { paper_id, printout_type_id } = req.query;
    if (!paper_id || !printout_type_id) {
      return sendError(res, 'paper_id and printout_type_id query params are required');
    }

    const sql = `
      SELECT r.*, p.paper_name, pt.name AS printout_type_name 
      FROM rates r
      JOIN papers p ON r.paper_id = p.id
      JOIN printout_types pt ON r.printout_type_id = pt.id
      WHERE r.paper_id = ? AND r.printout_type_id = ? AND r.is_active = 1
      LIMIT 1
    `;
    const rows = await query(sql, [paper_id, printout_type_id]);
    if (rows.length === 0) {
      return sendError(res, 'No configured rate found in database for the selected Paper and Printout Type', [], 444);
    }
    return sendSuccess(res, rows[0], 'Rate retrieved successfully');
  } catch (err) { next(err); }
}

async function createRate(req, res, next) {
  try {
    const { paper_id, printout_type_id, first_copy_rate, additional_copy_rate, click_rate } = req.body;
    if (!paper_id || !printout_type_id || first_copy_rate === undefined || additional_copy_rate === undefined) {
      return sendError(res, 'paper_id, printout_type_id, first_copy_rate, and additional_copy_rate are required');
    }

    const existing = await query('SELECT id FROM rates WHERE paper_id = ? AND printout_type_id = ?', [paper_id, printout_type_id]);
    if (existing.length > 0) {
      return sendError(res, 'A rate entry already exists for this Paper and Printout Type. Update the existing rate record.');
    }

    const result = await query(
      'INSERT INTO rates (paper_id, printout_type_id, first_copy_rate, additional_copy_rate, click_rate, is_active) VALUES (?, ?, ?, ?, ?, 1)',
      [paper_id, printout_type_id, first_copy_rate, additional_copy_rate, click_rate !== undefined ? click_rate : 0.00]
    );

    const created = await query('SELECT * FROM rates WHERE id = ?', [result.insertId]);
    return sendSuccess(res, created[0], 'Rate entry created successfully', 201);
  } catch (err) { next(err); }
}

async function updateRate(req, res, next) {
  try {
    const { id } = req.params;
    const { first_copy_rate, additional_copy_rate, click_rate, is_active } = req.body;

    const existing = await query('SELECT id FROM rates WHERE id = ?', [id]);
    if (existing.length === 0) return sendError(res, 'Rate record not found', [], 404);

    await query(
      'UPDATE rates SET first_copy_rate = ?, additional_copy_rate = ?, click_rate = ?, is_active = ? WHERE id = ?',
      [first_copy_rate, additional_copy_rate, click_rate !== undefined ? click_rate : 0.00, is_active !== undefined ? is_active : 1, id]
    );

    const updated = await query('SELECT * FROM rates WHERE id = ?', [id]);
    return sendSuccess(res, updated[0], 'Rate record updated successfully');
  } catch (err) { next(err); }
}

module.exports = {
  getRates,
  lookupRate,
  createRate,
  updateRate
};
