// CHANGE-2026-09-07: Created Supplier Purchases controller with automatic Stock IN updating inside SQL transactions.

const { query, withTransaction } = require('../db/index');
const { sendSuccess, sendError } = require('../utils/response');
const { calculateInvoiceTax } = require('../utils/calculator');

async function getPurchases(req, res, next) {
  try {
    const { supplier_id } = req.query;
    let sql = `
      SELECT p.*, s.supplier_name 
      FROM supplier_purchases p
      JOIN suppliers s ON p.supplier_id = s.id
      WHERE 1=1
    `;
    const params = [];
    if (supplier_id) {
      sql += ' AND p.supplier_id = ?';
      params.push(supplier_id);
    }
    sql += ' ORDER BY p.id DESC';
    const rows = await query(sql, params);
    return sendSuccess(res, rows, 'Supplier purchases fetched successfully');
  } catch (err) { next(err); }
}

async function getPurchaseById(req, res, next) {
  try {
    const { id } = req.params;
    const purchases = await query('SELECT p.*, s.supplier_name FROM supplier_purchases p JOIN suppliers s ON p.supplier_id = s.id WHERE p.id = ?', [id]);
    if (purchases.length === 0) return sendError(res, 'Purchase record not found', [], 404);
    const purchase = purchases[0];
    purchase.items = await query('SELECT spi.*, paper.paper_name FROM supplier_purchase_items spi JOIN papers paper ON spi.paper_id = paper.id WHERE spi.supplier_purchase_id = ?', [id]);
    return sendSuccess(res, purchase, 'Purchase details fetched successfully');
  } catch (err) { next(err); }
}

async function createPurchase(req, res, next) {
  try {
    const { supplier_id, purchase_date, invoice_number, items, paid_amount, tax_percentage } = req.body;
    if (!supplier_id || !purchase_date || !Array.isArray(items) || items.length === 0) {
      return sendError(res, 'supplier_id, purchase_date, and non-empty items array are required');
    }

    const suppliers = await query('SELECT * FROM suppliers WHERE id = ?', [supplier_id]);
    if (suppliers.length === 0) return sendError(res, 'Supplier not found in Supplier Master', [], 404);
    const supplier = suppliers[0];

    const companies = await query('SELECT * FROM companies ORDER BY id ASC LIMIT 1');
    if (companies.length === 0) return sendError(res, 'Company profile not configured', [], 404);
    const company = companies[0];

    let subtotal = 0;
    const processedItems = [];

    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const paperRows = await query('SELECT * FROM papers WHERE id = ?', [item.paper_id]);
      if (paperRows.length === 0) return sendError(res, `Paper ID ${item.paper_id} at line ${i + 1} not found`);
      const paper = paperRows[0];

      const qty = parseFloat(item.quantity || 0);
      const rate = parseFloat(item.rate || 0);
      if (qty <= 0 || rate < 0) return sendError(res, `Invalid quantity or rate at line ${i + 1}`);

      const amt = qty * rate;
      subtotal += amt;

      processedItems.push({
        paper_id: paper.id,
        quantity: qty,
        rate: rate,
        amount: amt,
        current_stock: paper.current_stock
      });
    }

    // Dynamic Tax Calculation
    const taxPct = parseFloat(tax_percentage || 0);
    const mockTaxMaster = { tax_percentage: taxPct, sub_taxes: [] };
    const taxResult = calculateInvoiceTax(company.state, supplier.state, subtotal, mockTaxMaster);

    const paidAmt = parseFloat(paid_amount || 0);
    const balAmt = taxResult.grandTotal - paidAmt;

    const createdPurchase = await withTransaction(async (conn) => {
      // 1. Generate Purchase Number
      const [countRes] = await conn.execute('SELECT COUNT(id) AS cnt FROM supplier_purchases');
      const seq = (countRes[0].cnt + 1).toString().padStart(4, '0');
      const purchaseNumber = `PUR-${new Date().getFullYear()}-${seq}`;

      // 2. Insert Header
      const [purInsert] = await conn.execute(
        `INSERT INTO supplier_purchases 
          (purchase_number, purchase_date, supplier_id, invoice_number, subtotal, cgst_amount, sgst_amount, igst_amount, grand_total, paid_amount, balance_amount)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          purchaseNumber,
          purchase_date,
          supplier_id,
          invoice_number || null,
          subtotal,
          taxResult.cgstAmount,
          taxResult.sgstAmount,
          taxResult.igstAmount,
          taxResult.grandTotal,
          paidAmt,
          balAmt
        ]
      );

      const purchaseId = purInsert.insertId;

      // 3. Insert Items & Update Stock IN
      for (const item of processedItems) {
        const itemTaxAmt = (item.amount * taxPct) / 100;
        const itemTotal = item.amount + itemTaxAmt;

        await conn.execute(
          `INSERT INTO supplier_purchase_items 
            (supplier_purchase_id, paper_id, quantity, rate, amount, tax_percentage, tax_amount, total_amount)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            purchaseId,
            item.paper_id,
            item.quantity,
            item.rate,
            item.amount,
            taxPct,
            itemTaxAmt,
            itemTotal
          ]
        );

        // Update Paper Stock IN
        const newStock = item.current_stock + item.quantity;
        await conn.execute('UPDATE papers SET current_stock = ? WHERE id = ?', [newStock, item.paper_id]);

        // Insert Stock Ledger Entry
        await conn.execute(
          `INSERT INTO stock_ledger 
            (paper_id, transaction_type, reference_id, qty_in, qty_out, balance_qty, remarks)
           VALUES (?, 'PURCHASE', ?, ?, 0.00, ?, ?)`,
          [
            item.paper_id,
            purchaseNumber,
            item.quantity,
            newStock,
            `Supplier Purchase #${purchaseNumber}`
          ]
        );
      }

      const [resPur] = await conn.execute('SELECT * FROM supplier_purchases WHERE id = ?', [purchaseId]);
      return resPur[0];
    });

    return sendSuccess(res, createdPurchase, 'Supplier purchase recorded successfully', 201);
  } catch (err) { next(err); }
}

module.exports = {
  getPurchases,
  getPurchaseById,
  createPurchase
};
