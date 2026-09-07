// CHANGE-2026-09-07: Created Financial Reporting Engine controller including Customer Aging Report.

const { query } = require('../db/index');
const { sendSuccess, sendError } = require('../utils/response');

/**
 * GET /api/reports/daily-sales
 */
async function getDailySalesReport(req, res, next) {
  try {
    const { start_date, end_date } = req.query;
    let sql = `
      SELECT 
        bill_date,
        COUNT(id) AS bill_count,
        COUNT(DISTINCT customer_id) AS customer_count,
        SUM(subtotal) AS total_subtotal,
        SUM(cgst_amount) AS total_cgst,
        SUM(sgst_amount) AS total_sgst,
        SUM(igst_amount) AS total_igst,
        SUM(grand_total) AS grand_total,
        SUM(paid_amount) AS total_paid,
        SUM(balance_amount) AS total_outstanding
      FROM sales_bills
      WHERE 1=1
    `;
    const params = [];
    if (start_date) {
      sql += ' AND bill_date >= ?';
      params.push(start_date);
    }
    if (end_date) {
      sql += ' AND bill_date <= ?';
      params.push(end_date);
    }
    sql += ' GROUP BY bill_date ORDER BY bill_date DESC';
    const rows = await query(sql, params);
    return sendSuccess(res, rows, 'Daily sales report generated successfully');
  } catch (err) { next(err); }
}

/**
 * GET /api/reports/customer-wise
 */
async function getCustomerWiseReport(req, res, next) {
  try {
    const sql = `
      SELECT 
        c.id AS customer_id,
        c.customer_name,
        c.phone,
        c.email,
        c.advance_balance,
        COUNT(b.id) AS bill_count,
        COALESCE(SUM(b.grand_total), 0) AS total_billed,
        COALESCE(SUM(b.paid_amount), 0) AS total_paid,
        COALESCE(SUM(b.balance_amount), 0) AS total_outstanding
      FROM customers c
      LEFT JOIN sales_bills b ON c.id = b.customer_id
      GROUP BY c.id
      ORDER BY total_outstanding DESC, c.customer_name ASC
    `;
    const rows = await query(sql);
    return sendSuccess(res, rows, 'Customer-wise sales report generated successfully');
  } catch (err) { next(err); }
}

/**
 * GET /api/reports/supplier-purchases
 */
async function getSupplierPurchasesReport(req, res, next) {
  try {
    const sql = `
      SELECT 
        s.id AS supplier_id,
        s.supplier_name,
        COUNT(p.id) AS purchase_count,
        COALESCE(SUM(p.subtotal), 0) AS total_subtotal,
        COALESCE(SUM(p.cgst_amount), 0) AS total_cgst,
        COALESCE(SUM(p.sgst_amount), 0) AS total_sgst,
        COALESCE(SUM(p.igst_amount), 0) AS total_igst,
        COALESCE(SUM(p.grand_total), 0) AS grand_total,
        COALESCE(SUM(p.paid_amount), 0) AS total_paid,
        COALESCE(SUM(p.balance_amount), 0) AS total_outstanding
      FROM suppliers s
      LEFT JOIN supplier_purchases p ON s.id = p.supplier_id
      GROUP BY s.id
      ORDER BY grand_total DESC
    `;
    const rows = await query(sql);
    return sendSuccess(res, rows, 'Supplier purchases report generated successfully');
  } catch (err) { next(err); }
}

/**
 * GET /api/reports/customer-pending
 */
async function getCustomerPendingReport(req, res, next) {
  try {
    const { customer_id } = req.query;
    let sql = `
      SELECT 
        b.id AS bill_id,
        b.bill_number,
        b.bill_date,
        c.customer_name,
        c.phone AS customer_phone,
        b.grand_total,
        b.paid_amount,
        b.balance_amount,
        DATEDIFF(CURRENT_DATE, b.bill_date) AS days_pending,
        b.status
      FROM sales_bills b
      JOIN customers c ON b.customer_id = c.id
      WHERE b.status IN ('UNPAID', 'PARTIAL')
    `;
    const params = [];
    if (customer_id) {
      sql += ' AND b.customer_id = ?';
      params.push(customer_id);
    }
    sql += ' ORDER BY days_pending DESC, b.bill_date ASC';
    const rows = await query(sql, params);
    return sendSuccess(res, rows, 'Customer pending bills report generated successfully');
  } catch (err) { next(err); }
}

/**
 * GET /api/reports/customer-aging
 * Customer Aging Report categorizing pending bills into 0-30, 31-60, 61-90, and >90 days buckets from bill_date.
 */
async function getCustomerAgingReport(req, res, next) {
  try {
    const { customer_id } = req.query;
    let sql = `
      SELECT 
        c.id AS customer_id,
        c.customer_name,
        c.phone,
        c.email,
        COALESCE(SUM(CASE WHEN DATEDIFF(CURRENT_DATE, b.bill_date) BETWEEN 0 AND 30 THEN b.balance_amount ELSE 0 END), 0) AS bucket_0_30,
        COALESCE(SUM(CASE WHEN DATEDIFF(CURRENT_DATE, b.bill_date) BETWEEN 31 AND 60 THEN b.balance_amount ELSE 0 END), 0) AS bucket_31_60,
        COALESCE(SUM(CASE WHEN DATEDIFF(CURRENT_DATE, b.bill_date) BETWEEN 61 AND 90 THEN b.balance_amount ELSE 0 END), 0) AS bucket_61_90,
        COALESCE(SUM(CASE WHEN DATEDIFF(CURRENT_DATE, b.bill_date) > 90 THEN b.balance_amount ELSE 0 END), 0) AS bucket_over_90,
        COALESCE(SUM(b.balance_amount), 0) AS total_outstanding
      FROM customers c
      JOIN sales_bills b ON c.id = b.customer_id
      WHERE b.status IN ('UNPAID', 'PARTIAL')
    `;
    const params = [];
    if (customer_id) {
      sql += ' AND c.id = ?';
      params.push(customer_id);
    }
    sql += ' GROUP BY c.id ORDER BY total_outstanding DESC';
    const rows = await query(sql, params);
    return sendSuccess(res, rows, 'Customer Aging Report generated successfully');
  } catch (err) { next(err); }
}

/**
 * GET /api/reports/stock
 */
async function getStockReport(req, res, next) {
  try {
    const sql = `
      SELECT 
        p.id AS paper_id,
        p.paper_name,
        p.purchase_unit,
        p.opening_stock,
        COALESCE(SUM(sl.qty_in), 0) AS total_qty_in,
        COALESCE(SUM(sl.qty_out), 0) AS total_qty_out,
        p.current_stock,
        p.reorder_level
      FROM papers p
      LEFT JOIN stock_ledger sl ON p.id = sl.paper_id
      GROUP BY p.id
      ORDER BY p.paper_name ASC
    `;
    const rows = await query(sql);
    return sendSuccess(res, rows, 'Stock inventory report generated successfully');
  } catch (err) { next(err); }
}

module.exports = {
  getDailySalesReport,
  getCustomerWiseReport,
  getSupplierPurchasesReport,
  getCustomerPendingReport,
  getCustomerAgingReport,
  getStockReport
};
