// CHANGE-2026-09-07: Created Printout Type Master controller.

const { query } = require('../db/index');
const { sendSuccess, sendError } = require('../utils/response');

async function getPrintoutTypes(req, res, next) {
  try {
    const { active_only } = req.query;
    let sql = 'SELECT * FROM printout_types';
    if (active_only === 'true') sql += ' WHERE is_active = 1';
    sql += ' ORDER BY name ASC';
    const rows = await query(sql);
    return sendSuccess(res, rows, 'Printout types fetched successfully');
  } catch (err) { next(err); }
}

async function createPrintoutType(req, res, next) {
  try {
    const { name, sides, color_mode, description } = req.body;
    if (!name || !sides || !color_mode) {
      return sendError(res, 'Name, sides (Single/Double), and color_mode (Color/B/W) are required');
    }

    const result = await query(
      'INSERT INTO printout_types (name, sides, color_mode, description, is_active) VALUES (?, ?, ?, ?, 1)',
      [name, sides, color_mode, description || null]
    );

    const created = await query('SELECT * FROM printout_types WHERE id = ?', [result.insertId]);
    return sendSuccess(res, created[0], 'Printout type created successfully', 201);
  } catch (err) { next(err); }
}

async function updatePrintoutType(req, res, next) {
  try {
    const { id } = req.params;
    const { name, sides, color_mode, description, is_active } = req.body;

    const existing = await query('SELECT id FROM printout_types WHERE id = ?', [id]);
    if (existing.length === 0) return sendError(res, 'Printout type not found', [], 404);

    await query(
      'UPDATE printout_types SET name = ?, sides = ?, color_mode = ?, description = ?, is_active = ? WHERE id = ?',
      [name, sides, color_mode, description || null, is_active !== undefined ? is_active : 1, id]
    );

    const updated = await query('SELECT * FROM printout_types WHERE id = ?', [id]);
    return sendSuccess(res, updated[0], 'Printout type updated successfully');
  } catch (err) { next(err); }
}

module.exports = {
  getPrintoutTypes,
  createPrintoutType,
  updatePrintoutType
};
