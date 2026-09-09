// CHANGE-2026-09-08: Updated Financial Reporting Engine controller with Non-Estimate customer filtering, Bill-Wise Daily Sales, and Date/Customer filter options.
// CHANGE-2026-09-09: Added Customer Payment Report controller endpoint.

const { query } = require('../db/index');
const { sendSuccess, sendError } = require('../utils/response');

/**
 * GET /api/reports/daily-sales
 * Query params: start_date, end_date, customer_id
 * Returns bill-wise details for non-estimate customers along with summary totals.
 */
async function getDailySalesReport(req, res, next) {
  try {
    const { start_date, end_date, customer_id } = req.query;
    let sql = `
      SELECT 
        b.id AS bill_id,
        b.bill_number,
        b.bill_date,
        b.customer_id,
        c.customer_name,
        b.subtotal,
        b.cgst_amount,
        b.sgst_amount,
        b.igst_amount,
        b.round_off,
        b.grand_total,
        b.paid_amount,
        b.balance_amount,
        b.status
      FROM sales_bills b
      JOIN customers c ON b.customer_id = c.id
      WHERE c.is_estimate = 0
    `;
    const params = [];
    if (start_date) {
      sql += ' AND b.bill_date >= ?';
      params.push(start_date);
    }
    if (end_date) {
      sql += ' AND b.bill_date <= ?';
      params.push(end_date);
    }
    if (customer_id) {
      sql += ' AND b.customer_id = ?';
      params.push(customer_id);
    }
    sql += ' ORDER BY b.bill_date DESC, b.id DESC';
    const bills = await query(sql, params);

    let totalSubtotal = 0;
    let totalCgst = 0;
    let totalSgst = 0;
    let totalIgst = 0;
    let totalRoundOff = 0;
    let grandTotal = 0;
    let totalPaid = 0;
    let totalOutstanding = 0;

    bills.forEach(row => {
      totalSubtotal += Number(row.subtotal || 0);
      totalCgst += Number(row.cgst_amount || 0);
      totalSgst += Number(row.sgst_amount || 0);
      totalIgst += Number(row.igst_amount || 0);
      totalRoundOff += Number(row.round_off || 0);
      grandTotal += Number(row.grand_total || 0);
      totalPaid += Number(row.paid_amount || 0);
      totalOutstanding += Number(row.balance_amount || 0);
    });

    const summary = {
      total_bills: bills.length,
      total_subtotal: totalSubtotal,
      total_cgst: totalCgst,
      total_sgst: totalSgst,
      total_igst: totalIgst,
      total_round_off: totalRoundOff,
      grand_total: grandTotal,
      total_paid: totalPaid,
      total_outstanding: totalOutstanding
    };

    return sendSuccess(res, { bills, summary }, 'Daily sales report generated successfully');
  } catch (err) { next(err); }
}

/**
 * GET /api/reports/customer-wise
 * Displays ONLY non-estimate customers (c.is_estimate = 0)
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
        COALESCE(SUM(b.subtotal), 0) AS total_subtotal,
        COALESCE(SUM(b.cgst_amount), 0) AS total_cgst,
        COALESCE(SUM(b.sgst_amount), 0) AS total_sgst,
        COALESCE(SUM(b.igst_amount), 0) AS total_igst,
        COALESCE(SUM(b.round_off), 0) AS total_round_off,
        COALESCE(SUM(b.grand_total), 0) AS total_billed,
        COALESCE(SUM(b.paid_amount), 0) AS total_paid,
        COALESCE(SUM(b.balance_amount), 0) AS total_outstanding
      FROM customers c
      LEFT JOIN sales_bills b ON c.id = b.customer_id
      WHERE c.is_estimate = 0
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
      WHERE c.is_estimate = 0 AND b.status IN ('UNPAID', 'PARTIAL')
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
      WHERE c.is_estimate = 0 AND b.status IN ('UNPAID', 'PARTIAL')
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

/**
 * GET /api/reports/customer-payment?customer_id=...
 * Returns payment history and payment-to-bill allocations for the specified customer.
 */
async function getCustomerPaymentReport(req, res, next) {
  try {
    const { customer_id } = req.query;
    if (!customer_id) {
      return sendError(res, 'customer_id query parameter is required');
    }

    const customers = await query('SELECT id, customer_name, phone, email, advance_balance FROM customers WHERE id = ?', [customer_id]);
    if (customers.length === 0) {
      return sendError(res, 'Customer not found in Customer Master.', [], 404);
    }
    const customer = customers[0];

    const sql = `
      SELECT 
        p.id AS payment_id,
        p.payment_number,
        p.payment_date,
        p.amount AS payment_amount,
        p.allocated_amount AS total_payment_allocated,
        p.advance_credit_amount,
        p.payment_mode,
        p.reference_number,
        p.notes,
        pa.id AS allocation_id,
        pa.sales_bill_id,
        pa.allocated_amount AS bill_allocated_amount,
        b.bill_number,
        b.bill_date,
        b.grand_total AS bill_grand_total,
        b.paid_amount AS bill_paid_amount,
        b.balance_amount AS bill_balance_amount,
        b.status AS bill_status
      FROM customer_payments p
      LEFT JOIN payment_allocations pa ON p.id = pa.payment_id
      LEFT JOIN sales_bills b ON pa.sales_bill_id = b.id
      WHERE p.customer_id = ?
      ORDER BY p.payment_date DESC, p.id DESC, pa.id ASC
    `;
    const rows = await query(sql, [customer_id]);

    const paymentsMap = new Map();
    let totalPayments = 0;
    let totalAllocated = 0;

    rows.forEach(r => {
      if (!paymentsMap.has(r.payment_id)) {
        totalPayments += Number(r.payment_amount || 0);
        paymentsMap.set(r.payment_id, {
          id: r.payment_id,
          payment_number: r.payment_number,
          payment_date: r.payment_date,
          amount: Number(r.payment_amount || 0),
          allocated_amount: Number(r.total_payment_allocated || 0),
          advance_credit_amount: Number(r.advance_credit_amount || 0),
          payment_mode: r.payment_mode,
          reference_number: r.reference_number,
          notes: r.notes,
          allocations: []
        });
      }

      if (r.allocation_id) {
        const p = paymentsMap.get(r.payment_id);
        totalAllocated += Number(r.bill_allocated_amount || 0);
        p.allocations.push({
          allocation_id: r.allocation_id,
          sales_bill_id: r.sales_bill_id,
          bill_number: r.bill_number,
          bill_date: r.bill_date,
          bill_grand_total: Number(r.bill_grand_total || 0),
          bill_paid_amount: Number(r.bill_paid_amount || 0),
          allocated_amount: Number(r.bill_allocated_amount || 0),
          bill_balance_amount: Number(r.bill_balance_amount || 0),
          bill_status: r.bill_status
        });
      }
    });

    const paymentsList = Array.from(paymentsMap.values());

    const summary = {
      total_payments: totalPayments,
      total_allocated: totalAllocated,
      advance_credit: Number(customer.advance_balance || 0)
    };

    return sendSuccess(res, { customer, summary, payments: paymentsList }, 'Customer payment report generated successfully');
  } catch (err) { next(err); }
}

module.exports = {
  getDailySalesReport,
  getCustomerWiseReport,
  getSupplierPurchasesReport,
  getCustomerPendingReport,
  getCustomerAgingReport,
  getStockReport,
  getCustomerPaymentReport
};
