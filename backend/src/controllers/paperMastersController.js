// CHANGE-2026-09-07: Created controllers for Paper Types, GSM, Paper Sizes, and Unified Paper Master.

const { query } = require('../db/index');
const { sendSuccess, sendError } = require('../utils/response');

// ==========================================
// 1. PAPER TYPES
// ==========================================
async function getPaperTypes(req, res, next) {
  try {
    const rows = await query('SELECT * FROM paper_types ORDER BY name ASC');
    return sendSuccess(res, rows, 'Paper types fetched successfully');
  } catch (err) { next(err); }
}

async function createPaperType(req, res, next) {
  try {
    const { name, description } = req.body;
    if (!name) return sendError(res, 'Paper type name is required');
    const result = await query('INSERT INTO paper_types (name, description, is_active) VALUES (?, ?, 1)', [name, description || null]);
    const created = await query('SELECT * FROM paper_types WHERE id = ?', [result.insertId]);
    return sendSuccess(res, created[0], 'Paper type created successfully', 201);
  } catch (err) { next(err); }
}

async function updatePaperType(req, res, next) {
  try {
    const { id } = req.params;
    const { name, description, is_active } = req.body;
    await query('UPDATE paper_types SET name = ?, description = ?, is_active = ? WHERE id = ?', [name, description || null, is_active !== undefined ? is_active : 1, id]);
    const updated = await query('SELECT * FROM paper_types WHERE id = ?', [id]);
    return sendSuccess(res, updated[0], 'Paper type updated successfully');
  } catch (err) { next(err); }
}

// ==========================================
// 2. PAPER GSM
// ==========================================
async function getPaperGsm(req, res, next) {
  try {
    const rows = await query('SELECT * FROM paper_gsm ORDER BY gsm_value ASC');
    return sendSuccess(res, rows, 'Paper GSM values fetched successfully');
  } catch (err) { next(err); }
}

async function createPaperGsm(req, res, next) {
  try {
    const { gsm_value, description } = req.body;
    if (!gsm_value) return sendError(res, 'GSM value is required');
    const result = await query('INSERT INTO paper_gsm (gsm_value, description, is_active) VALUES (?, ?, 1)', [gsm_value, description || null]);
    const created = await query('SELECT * FROM paper_gsm WHERE id = ?', [result.insertId]);
    return sendSuccess(res, created[0], 'Paper GSM created successfully', 201);
  } catch (err) { next(err); }
}

async function updatePaperGsm(req, res, next) {
  try {
    const { id } = req.params;
    const { gsm_value, description, is_active } = req.body;
    await query('UPDATE paper_gsm SET gsm_value = ?, description = ?, is_active = ? WHERE id = ?', [gsm_value, description || null, is_active !== undefined ? is_active : 1, id]);
    const updated = await query('SELECT * FROM paper_gsm WHERE id = ?', [id]);
    return sendSuccess(res, updated[0], 'Paper GSM updated successfully');
  } catch (err) { next(err); }
}

// ==========================================
// 3. PAPER SIZES
// ==========================================
async function getPaperSizes(req, res, next) {
  try {
    const rows = await query('SELECT * FROM paper_sizes ORDER BY name ASC');
    return sendSuccess(res, rows, 'Paper sizes fetched successfully');
  } catch (err) { next(err); }
}

async function createPaperSize(req, res, next) {
  try {
    const { name, description } = req.body;
    if (!name) return sendError(res, 'Paper size name is required');
    const result = await query('INSERT INTO paper_sizes (name, description, is_active) VALUES (?, ?, 1)', [name, description || null]);
    const created = await query('SELECT * FROM paper_sizes WHERE id = ?', [result.insertId]);
    return sendSuccess(res, created[0], 'Paper size created successfully', 201);
  } catch (err) { next(err); }
}

async function updatePaperSize(req, res, next) {
  try {
    const { id } = req.params;
    const { name, description, is_active } = req.body;
    await query('UPDATE paper_sizes SET name = ?, description = ?, is_active = ? WHERE id = ?', [name, description || null, is_active !== undefined ? is_active : 1, id]);
    const updated = await query('SELECT * FROM paper_sizes WHERE id = ?', [id]);
    return sendSuccess(res, updated[0], 'Paper size updated successfully');
  } catch (err) { next(err); }
}

// ==========================================
// 4. PAPERS (UNIFIED MASTER)
// ==========================================
async function getAllPapers(req, res, next) {
  try {
    const { active_only } = req.query;
    let sql = `
      SELECT 
        p.*,
        pt.name AS paper_type_name,
        pg.gsm_value AS gsm_value,
        ps.name AS paper_size_name
      FROM papers p
      JOIN paper_types pt ON p.paper_type_id = pt.id
      JOIN paper_gsm pg ON p.paper_gsm_id = pg.id
      JOIN paper_sizes ps ON p.paper_size_id = ps.id
    `;
    if (active_only === 'true') {
      sql += ' WHERE p.is_active = 1';
    }
    sql += ' ORDER BY p.paper_name ASC';
    const rows = await query(sql);
    return sendSuccess(res, rows, 'Papers fetched successfully');
  } catch (err) { next(err); }
}

async function createPaper(req, res, next) {
  try {
    const {
      paper_name,
      paper_type_id,
      paper_gsm_id,
      paper_size_id,
      purchase_unit,
      opening_stock,
      reorder_level
    } = req.body;

    if (!paper_name || !paper_type_id || !paper_gsm_id || !paper_size_id) {
      return sendError(res, 'Paper name, type, GSM, and size are required');
    }

    const openStock = opening_stock || 0.00;

    const result = await query(
      `INSERT INTO papers 
        (paper_name, paper_type_id, paper_gsm_id, paper_size_id, purchase_unit, opening_stock, current_stock, reorder_level, is_active) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)`,
      [
        paper_name,
        paper_type_id,
        paper_gsm_id,
        paper_size_id,
        purchase_unit || 'Sheet',
        openStock,
        openStock, // Initial current_stock set to opening_stock
        reorder_level || 100.00
      ]
    );

    const paperId = result.insertId;

    // Record Opening Stock in Stock Ledger if openStock > 0
    if (openStock > 0) {
      await query(
        `INSERT INTO stock_ledger 
          (paper_id, transaction_type, reference_id, qty_in, qty_out, balance_qty, remarks) 
         VALUES (?, 'OPENING_STOCK', 'INIT', ?, 0.00, ?, 'Initial opening stock')`,
        [paperId, openStock, openStock]
      );
    }

    const created = await query('SELECT * FROM papers WHERE id = ?', [paperId]);
    return sendSuccess(res, created[0], 'Paper master created successfully', 201);
  } catch (err) { next(err); }
}

async function updatePaper(req, res, next) {
  try {
    const { id } = req.params;
    const {
      paper_name,
      paper_type_id,
      paper_gsm_id,
      paper_size_id,
      purchase_unit,
      reorder_level,
      is_active
    } = req.body;

    const existing = await query('SELECT id FROM papers WHERE id = ?', [id]);
    if (existing.length === 0) return sendError(res, 'Paper not found', [], 404);

    await query(
      `UPDATE papers SET 
        paper_name = ?, paper_type_id = ?, paper_gsm_id = ?, paper_size_id = ?, 
        purchase_unit = ?, reorder_level = ?, is_active = ? 
       WHERE id = ?`,
      [
        paper_name,
        paper_type_id,
        paper_gsm_id,
        paper_size_id,
        purchase_unit || 'Sheet',
        reorder_level || 100.00,
        is_active !== undefined ? is_active : 1,
        id
      ]
    );

    const updated = await query('SELECT * FROM papers WHERE id = ?', [id]);
    return sendSuccess(res, updated[0], 'Paper master updated successfully');
  } catch (err) { next(err); }
}

module.exports = {
  getPaperTypes, createPaperType, updatePaperType,
  getPaperGsm, createPaperGsm, updatePaperGsm,
  getPaperSizes, createPaperSize, updatePaperSize,
  getAllPapers, createPaper, updatePaper
};
