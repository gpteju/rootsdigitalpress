// CHANGE-2026-09-07: Created Stock Ledger and Inventory Status controller.

const { query } = require('../db/index');
const { sendSuccess, sendError } = require('../utils/response');

async function getStockSummary(req, res, next) {
  try {
    const sql = `
      SELECT 
        p.id AS paper_id,
        p.paper_name,
        pt.name AS paper_type_name,
        pg.gsm_value,
        ps.name AS paper_size_name,
        p.purchase_unit,
        p.opening_stock,
        p.current_stock,
        p.reorder_level,
        CASE WHEN p.current_stock <= p.reorder_level THEN 1 ELSE 0 END AS is_low_stock
      FROM papers p
      JOIN paper_types pt ON p.paper_type_id = pt.id
      JOIN paper_gsm pg ON p.paper_gsm_id = pg.id
      JOIN paper_sizes ps ON p.paper_size_id = ps.id
      ORDER BY p.paper_name ASC
    `;
    const rows = await query(sql);
    return sendSuccess(res, rows, 'Stock summary fetched successfully');
  } catch (err) { next(err); }
}

async function getStockLedger(req, res, next) {
  try {
    const { paper_id, start_date, end_date } = req.query;
    let sql = `
      SELECT 
        sl.*,
        p.paper_name,
        p.purchase_unit
      FROM stock_ledger sl
      JOIN papers p ON sl.paper_id = p.id
      WHERE 1=1
    `;
    const params = [];

    if (paper_id) {
      sql += ' AND sl.paper_id = ?';
      params.push(paper_id);
    }
    if (start_date) {
      sql += ' AND sl.transaction_date >= ?';
      params.push(start_date);
    }
    if (end_date) {
      sql += ' AND sl.transaction_date <= ?';
      params.push(end_date);
    }

    sql += ' ORDER BY sl.id DESC';
    const ledger = await query(sql, params);
    return sendSuccess(res, ledger, 'Stock ledger history fetched successfully');
  } catch (err) { next(err); }
}

async function adjustStock(req, res, next) {
  try {
    const { paper_id, adjustment_type, quantity, remarks } = req.body;
    // adjustment_type: 'IN' or 'OUT'
    const qty = parseFloat(quantity || 0);

    if (!paper_id || !adjustment_type || qty <= 0) {
      return sendError(res, 'paper_id, valid adjustment_type (IN/OUT), and positive quantity are required');
    }

    const papers = await query('SELECT * FROM papers WHERE id = ?', [paper_id]);
    if (papers.length === 0) return sendError(res, 'Paper not found', [], 404);
    const paper = papers[0];

    let qtyIn = 0;
    let qtyOut = 0;
    let newStock = paper.current_stock;

    if (adjustment_type === 'IN') {
      qtyIn = qty;
      newStock += qty;
    } else if (adjustment_type === 'OUT') {
      if (paper.current_stock < qty) {
        return sendError(res, `Cannot deduct ${qty} ${paper.purchase_unit}. Current stock is ${paper.current_stock}.`);
      }
      qtyOut = qty;
      newStock -= qty;
    } else {
      return sendError(res, 'Invalid adjustment_type. Must be IN or OUT.');
    }

    await query('UPDATE papers SET current_stock = ? WHERE id = ?', [newStock, paper_id]);
    await query(
      `INSERT INTO stock_ledger (paper_id, transaction_type, reference_id, qty_in, qty_out, balance_qty, remarks)
       VALUES (?, 'ADJUSTMENT', 'MANUAL', ?, ?, ?, ?)`,
      [paper_id, qtyIn, qtyOut, newStock, remarks || 'Manual Stock Adjustment']
    );

    return sendSuccess(res, { paper_id, new_stock: newStock }, 'Stock adjusted successfully');
  } catch (err) { next(err); }
}

module.exports = {
  getStockSummary,
  getStockLedger,
  adjustStock
};
