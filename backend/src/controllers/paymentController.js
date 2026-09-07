// CHANGE-2026-09-07: Created Customer Payments controller supporting FIFO and Manual allocation algorithms with Customer Advance credit handling.

const { query, withTransaction } = require('../db/index');
const { sendSuccess, sendError } = require('../utils/response');

async function getPayments(req, res, next) {
  try {
    const { customer_id } = req.query;
    let sql = `
      SELECT p.*, c.customer_name 
      FROM customer_payments p
      JOIN customers c ON p.customer_id = c.id
      WHERE 1=1
    `;
    const params = [];
    if (customer_id) {
      sql += ' AND p.customer_id = ?';
      params.push(customer_id);
    }
    sql += ' ORDER BY p.id DESC';
    const rows = await query(sql, params);
    return sendSuccess(res, rows, 'Customer payments fetched successfully');
  } catch (err) { next(err); }
}

async function getCustomerPendingBills(req, res, next) {
  try {
    const { customerId } = req.params;
    const pendingBills = await query(
      `SELECT id, bill_number, bill_date, grand_total, paid_amount, balance_amount, status 
       FROM sales_bills 
       WHERE customer_id = ? AND status IN ('UNPAID', 'PARTIAL')
       ORDER BY bill_date ASC, id ASC`,
      [customerId]
    );
    return sendSuccess(res, pendingBills, 'Pending customer bills fetched successfully');
  } catch (err) { next(err); }
}

async function processPayment(req, res, next) {
  try {
    const {
      customer_id,
      payment_date,
      amount,
      allocation_mode, // 'FIFO' or 'MANUAL'
      manual_allocations, // Array of { sales_bill_id, allocated_amount }
      payment_mode,
      reference_number,
      notes
    } = req.body;

    const paymentAmount = parseFloat(amount || 0);
    if (!customer_id || !payment_date || paymentAmount <= 0 || !allocation_mode) {
      return sendError(res, 'customer_id, payment_date, valid positive amount, and allocation_mode (FIFO/MANUAL) are required');
    }

    const customers = await query('SELECT * FROM customers WHERE id = ?', [customer_id]);
    if (customers.length === 0) return sendError(res, 'Customer not found in Customer Master.', [], 404);

    const createdPayment = await withTransaction(async (conn) => {
      // 1. Generate Receipt Number
      const [countRes] = await conn.execute('SELECT COUNT(id) AS cnt FROM customer_payments');
      const seq = (countRes[0].cnt + 1).toString().padStart(4, '0');
      const paymentNumber = `REC-${new Date().getFullYear()}-${seq}`;

      let remainingPayment = paymentAmount;
      let totalAllocated = 0;
      let advanceCredit = 0;
      const allocationRecords = [];

      if (allocation_mode === 'FIFO') {
        // Fetch unpaid / partial bills ordered strictly by bill_date ASC, id ASC
        const [pendingBills] = await conn.execute(
          `SELECT id, bill_number, grand_total, paid_amount, balance_amount 
           FROM sales_bills 
           WHERE customer_id = ? AND status IN ('UNPAID', 'PARTIAL')
           ORDER BY bill_date ASC, id ASC`,
          [customer_id]
        );

        for (const bill of pendingBills) {
          if (remainingPayment <= 0) break;
          const billBal = parseFloat(bill.balance_amount);
          const alloc = Math.min(remainingPayment, billBal);

          remainingPayment -= alloc;
          totalAllocated += alloc;

          const newPaid = parseFloat(bill.paid_amount) + alloc;
          const newBal = billBal - alloc;
          const newStatus = newBal <= 0.001 ? 'PAID' : 'PARTIAL';

          await conn.execute(
            'UPDATE sales_bills SET paid_amount = ?, balance_amount = ?, status = ? WHERE id = ?',
            [newPaid, newBal, newStatus, bill.id]
          );

          allocationRecords.push({ sales_bill_id: bill.id, allocated_amount: alloc });
        }

        // Remaining payment beyond all pending bills becomes Customer Advance Credit
        if (remainingPayment > 0) {
          advanceCredit = remainingPayment;
          await conn.execute(
            'UPDATE customers SET advance_balance = advance_balance + ? WHERE id = ?',
            [advanceCredit, customer_id]
          );
        }
      } else if (allocation_mode === 'MANUAL') {
        if (!Array.isArray(manual_allocations)) {
          throw new Error('manual_allocations array is required for MANUAL allocation mode');
        }

        for (const allocItem of manual_allocations) {
          const allocAmt = parseFloat(allocItem.allocated_amount || 0);
          if (allocAmt <= 0) continue;

          const [billRows] = await conn.execute('SELECT * FROM sales_bills WHERE id = ? AND customer_id = ?', [allocItem.sales_bill_id, customer_id]);
          if (billRows.length === 0) throw new Error(`Bill ID ${allocItem.sales_bill_id} not found for customer`);
          const bill = billRows[0];
          const billBal = parseFloat(bill.balance_amount);

          if (allocAmt > billBal + 0.01) {
            throw new Error(`Allocated amount ₹${allocAmt} exceeds balance ₹${billBal} for Bill ${bill.bill_number}`);
          }

          totalAllocated += allocAmt;
          const newPaid = parseFloat(bill.paid_amount) + allocAmt;
          const newBal = billBal - allocAmt;
          const newStatus = newBal <= 0.001 ? 'PAID' : 'PARTIAL';

          await conn.execute(
            'UPDATE sales_bills SET paid_amount = ?, balance_amount = ?, status = ? WHERE id = ?',
            [newPaid, newBal, newStatus, bill.id]
          );

          allocationRecords.push({ sales_bill_id: bill.id, allocated_amount: allocAmt });
        }

        if (paymentAmount > totalAllocated) {
          advanceCredit = paymentAmount - totalAllocated;
          await conn.execute(
            'UPDATE customers SET advance_balance = advance_balance + ? WHERE id = ?',
            [advanceCredit, customer_id]
          );
        }
      } else {
        throw new Error(`Unsupported allocation mode "${allocation_mode}"`);
      }

      // Record Customer Payment Header
      const [payInsert] = await conn.execute(
        `INSERT INTO customer_payments 
          (payment_number, payment_date, customer_id, amount, allocated_amount, advance_credit_amount, payment_mode, reference_number, notes)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          paymentNumber,
          payment_date,
          customer_id,
          paymentAmount,
          totalAllocated,
          advanceCredit,
          payment_mode || 'CASH',
          reference_number || null,
          notes || null
        ]
      );

      const paymentId = payInsert.insertId;

      // Record Payment Allocations
      for (const rec of allocationRecords) {
        await conn.execute(
          'INSERT INTO payment_allocations (payment_id, sales_bill_id, allocated_amount) VALUES (?, ?, ?)',
          [paymentId, rec.sales_bill_id, rec.allocated_amount]
        );
      }

      const [resPay] = await conn.execute('SELECT * FROM customer_payments WHERE id = ?', [paymentId]);
      return resPay[0];
    });

    return sendSuccess(res, createdPayment, 'Customer payment processed successfully', 201);
  } catch (err) { next(err); }
}

module.exports = {
  getPayments,
  getCustomerPendingBills,
  processPayment
};
