// CHANGE-2026-09-07: Created Sales Billing engine with stock validation, dynamic taxes, historical snapshots, and SQL transaction protection.

const { query, withTransaction } = require('../db/index');
const { sendSuccess, sendError } = require('../utils/response');
const { calculateItemAmount, calculateInvoiceTax } = require('../utils/calculator');
const PDFDocument = require('pdfkit');
const { sendInvoiceEmail } = require('../services/mailService');
const { buildPdfBuffer } = require('../services/pdfService');
const { generateThermalReceipt, sendToPrinter } = require('../services/thermalPrinterService');

/**
 * Helper to build PDF Buffer for a Sales Bill with compact invoice dimensions and precise alignment.
 */
async function getSalesBills(req, res, next) {
  try {
    const { customer_id, status, start_date, end_date } = req.query;
    let sql = `
      SELECT 
        b.*,
        c.customer_name,
        c.phone AS customer_phone,
        c.email AS customer_email,
        t.tax_name,
        t.tax_percentage
      FROM sales_bills b
      JOIN customers c ON b.customer_id = c.id
      JOIN taxes t ON b.tax_id = t.id
      WHERE 1=1
    `;
    const params = [];

    if (customer_id) {
      sql += ' AND b.customer_id = ?';
      params.push(customer_id);
    }
    if (status) {
      sql += ' AND b.status = ?';
      params.push(status);
    }
    if (start_date) {
      sql += ' AND b.bill_date >= ?';
      params.push(start_date);
    }
    if (end_date) {
      sql += ' AND b.bill_date <= ?';
      params.push(end_date);
    }

    sql += ' ORDER BY b.id DESC';
    const bills = await query(sql, params);
    return sendSuccess(res, bills, 'Sales bills fetched successfully');
  } catch (err) { next(err); }
}

/**
 * GET /api/sales-bills/:id
 */
async function getSalesBillById(req, res, next) {
  try {
    const { id } = req.params;
    const bills = await query(
      `SELECT b.*, c.customer_name, c.address AS customer_address, c.city AS customer_city, 
              c.state AS customer_state, c.gstin AS customer_gstin, c.phone AS customer_phone, c.email AS customer_email,
              t.tax_name, t.tax_percentage
       FROM sales_bills b
       JOIN customers c ON b.customer_id = c.id
       JOIN taxes t ON b.tax_id = t.id
       WHERE b.id = ?`,
      [id]
    );

    if (bills.length === 0) {
      return sendError(res, 'Sales bill not found', [], 404);
    }

    const bill = bills[0];
    bill.items = await query('SELECT * FROM sales_bill_items WHERE sales_bill_id = ?', [id]);
    bill.payment_history = await query(
      `SELECT pa.allocated_amount, pa.created_at, cp.payment_number, cp.payment_date, cp.payment_mode, cp.reference_number
       FROM payment_allocations pa
       JOIN customer_payments cp ON pa.payment_id = cp.id
       WHERE pa.sales_bill_id = ?
       ORDER BY pa.id ASC`,
      [id]
    );

    return sendSuccess(res, bill, 'Sales bill details fetched successfully');
  } catch (err) { next(err); }
}

/**
 * POST /api/sales-bills
 * Creates a new Sales Bill inside a single database transaction.
 */
async function createSalesBill(req, res, next) {
  try {
    const { customer_id, tax_id, bill_date, notes, items } = req.body;

    if (!customer_id || !tax_id || !bill_date || !Array.isArray(items) || items.length === 0) {
      return sendError(res, 'customer_id, tax_id, bill_date, and non-empty items array are required');
    }

    // 1. Fetch Company Master Profile
    const companies = await query('SELECT * FROM companies ORDER BY id ASC LIMIT 1');
    if (companies.length === 0) {
      return sendError(res, 'Company master profile is not configured. Configure Company Master first.');
    }
    const company = companies[0];

    // 2. Fetch Customer Master Profile
    const customers = await query('SELECT * FROM customers WHERE id = ?', [customer_id]);
    if (customers.length === 0) {
      return sendError(res, 'Selected customer does not exist in Customer Master.');
    }
    const customer = customers[0];

    // 3. Fetch Tax Master & Sub-taxes
    const taxes = await query('SELECT * FROM taxes WHERE id = ?', [tax_id]);
    if (taxes.length === 0) {
      return sendError(res, 'Selected tax master record does not exist.');
    }
    const taxMaster = taxes[0];
    taxMaster.sub_taxes = await query('SELECT * FROM tax_sub_taxes WHERE tax_id = ?', [tax_id]);

    // 4. Validate Stock & Pricing for each item
    const processedItems = [];
    let calculatedSubtotal = 0;

    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const paperRows = await query('SELECT p.*, pt.name AS type_name FROM papers p JOIN paper_types pt ON p.paper_type_id = pt.id WHERE p.id = ?', [item.paper_id]);
      if (paperRows.length === 0) {
        return sendError(res, `Paper item at line ${i + 1} does not exist in Paper Master.`);
      }
      const paper = paperRows[0];

      const printoutRows = await query('SELECT * FROM printout_types WHERE id = ?', [item.printout_type_id]);
      if (printoutRows.length === 0) {
        return sendError(res, `Printout type at line ${i + 1} does not exist in Printout Type Master.`);
      }
      const printout = printoutRows[0];

      // STOCK VALIDATION: Rule option A - Block if stock is insufficient
      const requestedQty = parseFloat(item.quantity || 0);
      if (requestedQty <= 0) {
        return sendError(res, `Invalid quantity "${requestedQty}" at line ${i + 1}. Quantity must be > 0.`);
      }
      if (paper.current_stock < requestedQty) {
        return sendError(
          res, 
          `Insufficient Stock for "${paper.paper_name}". Available Stock: ${paper.current_stock} ${paper.purchase_unit}, Requested: ${requestedQty} ${paper.purchase_unit}.`,
          [`Stock validation failed for paper ID ${paper.id}`],
          400
        );
      }

      // RATE LOOKUP: Rate Master lookup
      const rateRows = await query('SELECT * FROM rates WHERE paper_id = ? AND printout_type_id = ? AND is_active = 1', [paper.id, printout.id]);
      if (rateRows.length === 0) {
        return sendError(res, `No active rate defined in Rate Master for Paper "${paper.paper_name}" and Printout Type "${printout.name}".`);
      }
      const rateConfig = rateRows[0];

      // Pricing Calculation: Rate Based On (Rates vs Click Rate)
      const rateBasedOn = item.rate_based_on || 'Rates';
      const clickRateVal = parseFloat(item.click_rate !== undefined ? item.click_rate : (rateConfig.click_rate || 0));
      let lineAmount = 0;
      if (rateBasedOn === 'Click Rate') {
        lineAmount = parseFloat((clickRateVal * requestedQty).toFixed(2));
      } else {
        const calc = calculateItemAmount(requestedQty, rateConfig.first_copy_rate, rateConfig.additional_copy_rate);
        lineAmount = calc.lineAmount;
      }
      calculatedSubtotal += lineAmount;

      processedItems.push({
        paper_id: paper.id,
        printout_type_id: printout.id,
        paper_name_snapshot: paper.paper_name,
        job_name: item.job_name || null,
        printout_type_name_snapshot: printout.name,
        quantity: requestedQty,
        first_copy_rate: rateConfig.first_copy_rate,
        additional_copy_rate: rateConfig.additional_copy_rate,
        rate_based_on: rateBasedOn,
        click_rate: clickRateVal,
        calculated_amount: lineAmount,
        current_paper_stock: paper.current_stock
      });
    }

    // 5. Dynamic Tax Calculation
    const taxResult = calculateInvoiceTax(company.state, customer.state, calculatedSubtotal, taxMaster, company.state_code, customer.state_code);
    const rawTotal = taxResult.grandTotal;
    const finalGrandTotal = Math.round(rawTotal);
    const roundOff = parseFloat((finalGrandTotal - rawTotal).toFixed(2));

    // 6. Execute SQL Transaction to create Bill, Bill Items, update Stock & Ledger
    const createdBill = await withTransaction(async (conn) => {
      // Generate Invoice Number (Prefix + YYYY + sequential ID)
      const prefix = company.invoice_prefix || 'INV-';
      const [countResult] = await conn.execute('SELECT COUNT(id) AS cnt FROM sales_bills');
      const seq = (countResult[0].cnt + 1).toString().padStart(4, '0');
      const billNumber = `${prefix}${new Date().getFullYear()}-${seq}`;

      // Insert Bill Header
      const [billInsert] = await conn.execute(
        `INSERT INTO sales_bills 
          (bill_number, bill_date, customer_id, tax_id, company_state_snapshot, customer_state_snapshot, is_interstate,
           subtotal, cgst_amount, sgst_amount, igst_amount, round_off, grand_total, paid_amount, balance_amount, status, notes)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0.00, ?, 'UNPAID', ?)`,
        [
          billNumber,
          bill_date,
          customer_id,
          tax_id,
          company.state,
          customer.state,
          taxResult.isInterstate ? 1 : 0,
          calculatedSubtotal,
          taxResult.cgstAmount,
          taxResult.sgstAmount,
          taxResult.igstAmount,
          roundOff,
          finalGrandTotal,
          finalGrandTotal, // Initial balance_amount = finalGrandTotal
          notes || null
        ]
      );

      const billId = billInsert.insertId;

      // Insert Line Items & Deduct Stock
      for (const item of processedItems) {
        const itemTaxPct = taxMaster.tax_percentage || 0;
        const itemTaxAmt = (item.calculated_amount * itemTaxPct) / 100;
        const itemTotal = item.calculated_amount + itemTaxAmt;

        await conn.execute(
          `INSERT INTO sales_bill_items 
            (sales_bill_id, paper_id, printout_type_id, paper_name_snapshot, job_name, printout_type_name_snapshot,
             quantity, first_copy_rate, additional_copy_rate, rate_based_on, click_rate, calculated_amount, tax_percentage, tax_amount, total_amount)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            billId,
            item.paper_id,
            item.printout_type_id,
            item.paper_name_snapshot,
            item.job_name,
            item.printout_type_name_snapshot,
            item.quantity,
            item.first_copy_rate,
            item.additional_copy_rate,
            item.rate_based_on,
            item.click_rate,
            item.calculated_amount,
            itemTaxPct,
            itemTaxAmt,
            itemTotal
          ]
        );

        // Deduct Stock
        const newStock = item.current_paper_stock - item.quantity;
        await conn.execute('UPDATE papers SET current_stock = ? WHERE id = ?', [newStock, item.paper_id]);

        // Insert Stock Ledger Entry
        await conn.execute(
          `INSERT INTO stock_ledger 
            (paper_id, transaction_type, reference_id, qty_in, qty_out, balance_qty, remarks)
           VALUES (?, 'SALE', ?, 0.00, ?, ?, ?)`,
          [
            item.paper_id,
            billNumber,
            item.quantity,
            newStock,
            `Sales Bill #${billNumber}`
          ]
        );
      }

      const [bills] = await conn.execute(
        `SELECT b.*, c.customer_name, c.address AS customer_address, c.city AS customer_city, 
                c.state AS customer_state, c.gstin AS customer_gstin, c.phone AS customer_phone, c.email AS customer_email,
                t.tax_name, t.tax_percentage
         FROM sales_bills b
         JOIN customers c ON b.customer_id = c.id
         JOIN taxes t ON b.tax_id = t.id
         WHERE b.id = ?`,
        [billId]
      );
      const bill = bills[0];
      const [items] = await conn.execute('SELECT * FROM sales_bill_items WHERE sales_bill_id = ?', [billId]);
      bill.items = items;
      return bill;
    });

    return sendSuccess(res, createdBill, 'Sales Bill created successfully', 201);
  } catch (err) { next(err); }
}

/**
 * GET /api/sales-bills/:id/pdf
 * Generates invoice PDF stream.
 */
async function generateBillPdf(req, res, next) {
  try {
    const { id } = req.params;
    const bills = await query('SELECT * FROM sales_bills WHERE id = ?', [id]);
    if (bills.length === 0) return sendError(res, 'Bill not found', [], 404);
    const bill = bills[0];

    const customers = await query('SELECT * FROM customers WHERE id = ?', [bill.customer_id]);
    const customer = customers[0] || { customer_name: 'Cash' };

    const companies = await query('SELECT * FROM companies ORDER BY id ASC LIMIT 1');
    const company = companies[0] || { company_name: 'Printout Company' };

    const items = await query('SELECT * FROM sales_bill_items WHERE sales_bill_id = ?', [id]);

    const pdfBuffer = await buildPdfBuffer(bill, customer, company, items);

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename=Invoice_${bill.bill_number}.pdf`);
    return res.send(pdfBuffer);
  } catch (err) { next(err); }
}

/**
 * POST /api/sales-bills/:id/email
 * Emails bill PDF attachment to customer using Node.js Nodemailer service.
 */
async function emailBillPdf(req, res, next) {
  try {
    const { id } = req.params;
    const bills = await query('SELECT * FROM sales_bills WHERE id = ?', [id]);
    if (bills.length === 0) return sendError(res, 'Bill not found', [], 404);
    const bill = bills[0];

    const customers = await query('SELECT * FROM customers WHERE id = ?', [bill.customer_id]);
    if (customers.length === 0) return sendError(res, 'Customer not found', [], 404);
    const customer = customers[0];

    if (!customer.email || !customer.email.trim()) {
      return sendError(res, `Customer "${customer.customer_name}" does not have an email address registered in Customer Master.`, [], 400);
    }

    const companies = await query('SELECT * FROM companies ORDER BY id ASC LIMIT 1');
    const company = companies[0] || { company_name: 'Printout Company' };

    const items = await query('SELECT * FROM sales_bill_items WHERE sales_bill_id = ?', [id]);

    // 1. Generate Invoice PDF Buffer
    const pdfBuffer = await buildPdfBuffer(bill, customer, company, items);

    // 2. Dispatch Email via Nodemailer MailService
    await sendInvoiceEmail({
      to: customer.email,
      subject: `Invoice #${bill.bill_number} - ${company.company_name || 'Printout Billing'}`,
      text: `Dear ${customer.customer_name},\n\nPlease find attached your invoice #${bill.bill_number} for Rs. ${parseFloat(bill.grand_total).toFixed(2)}.\n\nThank you for your business!`,
      pdfBuffer,
      filename: `Invoice_${bill.bill_number}.pdf`
    });

    return sendSuccess(res, null, `Invoice PDF successfully emailed to ${customer.email}`);
  } catch (err) { next(err); }
}

/**
 * POST /api/sales-bills/:id/print
 * Generates and sends a 3-inch ESC/POS thermal receipt to configured TCP thermal printer.
 */
async function printSalesBill(req, res, next) {
  try {
    const { id } = req.params;

    // 1. Fetch Printer Configuration
    const settingsRows = await query('SELECT * FROM printer_settings ORDER BY id ASC LIMIT 1');
    if (settingsRows.length === 0 || settingsRows[0].printer_enabled !== 1) {
      return sendError(res, 'Thermal printer is currently DISABLED in Printer Configuration. Enable printer in Settings first.', [], 400);
    }
    const printerSettings = settingsRows[0];

    if (!printerSettings.printer_ip || !printerSettings.printer_ip.trim()) {
      return sendError(res, 'Printer IP address is not configured. Please save a valid Printer IP in Printer Configuration.', [], 400);
    }

    // 2. Fetch Authoritative Bill & Related Master Records from DB
    const bills = await query('SELECT * FROM sales_bills WHERE id = ?', [id]);
    if (bills.length === 0) return sendError(res, 'Sales bill not found', [], 404);
    const bill = bills[0];

    const customers = await query('SELECT * FROM customers WHERE id = ?', [bill.customer_id]);
    const customer = customers[0] || { customer_name: 'Cash' };

    const companies = await query('SELECT * FROM companies ORDER BY id ASC LIMIT 1');
    const company = companies[0] || { company_name: 'Printout Company' };

    const items = await query('SELECT * FROM sales_bill_items WHERE sales_bill_id = ?', [id]);

    // 3. Format 3-inch ESC/POS Thermal Receipt
    const receiptBuffer = generateThermalReceipt({
      company,
      customer,
      bill,
      items
    });

    // 4. Send to TCP Network Thermal Printer
    await sendToPrinter({
      ip: printerSettings.printer_ip,
      port: printerSettings.printer_port,
      data: receiptBuffer
    });

    return sendSuccess(res, null, `Sales Bill #${bill.bill_number} sent successfully to printer (${printerSettings.printer_ip}:${printerSettings.printer_port})`);
  } catch (err) { next(err); }
}

module.exports = {
  getSalesBills,
  getSalesBillById,
  createSalesBill,
  generateBillPdf,
  emailBillPdf,
  printSalesBill
};

