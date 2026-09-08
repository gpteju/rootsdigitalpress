// CHANGE-2026-09-08: Created Job Details Controller for handling Estimate / Job Customers without tax.

const { query, withTransaction } = require('../db/index');
const { sendSuccess, sendError } = require('../utils/response');
const { buildPdfBuffer } = require('../services/pdfService');
const { sendInvoiceEmail } = require('../services/mailService');
const { generateThermalReceipt, sendToPrinter } = require('../services/thermalPrinterService');

/**
 * GET /api/jobs
 * Retrieves all Estimate / Job details.
 */
async function getJobs(req, res, next) {
  try {
    const jobs = await query(`
      SELECT 
        j.*,
        c.customer_name,
        c.phone AS customer_phone,
        c.email AS customer_email
      FROM job_details j
      JOIN customers c ON j.customer_id = c.id
      ORDER BY j.created_at DESC
    `);
    return sendSuccess(res, jobs, 'Job estimates retrieved successfully');
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/jobs/:id
 */
async function getJobById(req, res, next) {
  try {
    const { id } = req.params;
    const jobs = await query('SELECT * FROM job_details WHERE id = ?', [id]);
    if (jobs.length === 0) {
      return sendError(res, 'Job estimate not found', [], 404);
    }
    const job = jobs[0];

    const customers = await query('SELECT * FROM customers WHERE id = ?', [job.customer_id]);
    const items = await query('SELECT * FROM job_detail_items WHERE job_detail_id = ?', [id]);

    return sendSuccess(res, { ...job, customer: customers[0], items }, 'Job estimate details retrieved successfully');
  } catch (err) {
    next(err);
  }
}

/**
 * POST /api/jobs
 * Creates a new Estimate / Job detail (Tax calculation forced to 0).
 */
async function createJob(req, res, next) {
  try {
    const { customer_id, items, notes } = req.body;

    if (!customer_id || !Array.isArray(items) || items.length === 0) {
      return sendError(res, 'Customer ID and at least one line item are required', []);
    }

    const createdJob = await withTransaction(async (conn) => {
      // 1. Validate Customer
      const [customers] = await conn.execute('SELECT * FROM customers WHERE id = ?', [customer_id]);
      if (customers.length === 0) throw new Error('Customer not found');
      const customer = customers[0];

      // 2. Fetch Company Settings for Estimate Number Prefix
      const [companies] = await conn.execute('SELECT * FROM companies ORDER BY id ASC LIMIT 1');
      const company = companies[0] || { company_name: 'Printout Company', estimate_prefix: 'JOB-' };
      const prefix = company.estimate_prefix || 'JOB-';

      // 3. Generate Job Number
      const [countResult] = await conn.execute('SELECT COUNT(id) AS cnt FROM job_details');
      const seq = (countResult[0].cnt + 1).toString().padStart(4, '0');
      const jobNumber = `${prefix}${new Date().getFullYear()}-${seq}`;
      const jobDate = new Date().toISOString().split('T')[0];

      // 4. Calculate Subtotal & Line Items
      let calculatedSubtotal = 0;
      const processedItems = [];

      for (const item of items) {
        const [papers] = await conn.execute('SELECT * FROM papers WHERE id = ?', [item.paper_id]);
        if (papers.length === 0) throw new Error(`Paper item not found: ${item.paper_id}`);
        const paper = papers[0];

        const [printouts] = await conn.execute('SELECT * FROM printout_types WHERE id = ?', [item.printout_type_id]);
        if (printouts.length === 0) throw new Error(`Printout type not found: ${item.printout_type_id}`);
        const printout = printouts[0];

        const quantity = parseFloat(item.quantity);
        if (isNaN(quantity) || quantity <= 0) throw new Error('Item quantity must be greater than 0');

        // Check Stock
        if (parseFloat(paper.current_stock) < quantity) {
          throw new Error(`Insufficient stock for paper '${paper.paper_name}'. Available: ${paper.current_stock}, Required: ${quantity}`);
        }

        const [rates] = await conn.execute(
          'SELECT * FROM rates WHERE paper_id = ? AND printout_type_id = ? AND is_active = 1',
          [item.paper_id, item.printout_type_id]
        );

        let firstCopyRate = 0;
        let additionalCopyRate = 0;
        let lineAmount = 0;

        if (rates.length > 0) {
          firstCopyRate = parseFloat(rates[0].first_copy_rate);
          additionalCopyRate = parseFloat(rates[0].additional_copy_rate);
          if (quantity === 1) {
            lineAmount = firstCopyRate;
          } else if (quantity > 1) {
            lineAmount = firstCopyRate + (quantity - 1) * additionalCopyRate;
          }
        } else {
          lineAmount = parseFloat(item.calculated_amount) || 0;
        }

        calculatedSubtotal += lineAmount;

        processedItems.push({
          paper_id: paper.id,
          printout_type_id: printout.id,
          paper_name_snapshot: paper.paper_name,
          printout_type_name_snapshot: printout.name || printout.type_name || '',
          quantity,
          first_copy_rate: firstCopyRate,
          additional_copy_rate: additionalCopyRate,
          calculated_amount: lineAmount,
          current_paper_stock: parseFloat(paper.current_stock)
        });
      }

      // 5. Insert Job Header (Grand Total = Subtotal, Tax = 0)
      const [jobInsert] = await conn.execute(
        `INSERT INTO job_details 
          (job_number, job_date, customer_id, subtotal, grand_total, notes, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          jobNumber,
          jobDate,
          customer_id,
          calculatedSubtotal,
          calculatedSubtotal, // No tax applied for job estimates
          notes || null,
          req.user?.id || null
        ]
      );

      const jobDetailId = jobInsert.insertId;

      // 6. Insert Line Items & Deduct Stock
      for (const item of processedItems) {
        await conn.execute(
          `INSERT INTO job_detail_items 
            (job_detail_id, paper_id, printout_type_id, paper_name_snapshot, printout_type_name_snapshot,
             quantity, first_copy_rate, additional_copy_rate, calculated_amount, total_amount)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            jobDetailId,
            item.paper_id,
            item.printout_type_id,
            item.paper_name_snapshot || '',
            item.printout_type_name_snapshot || '',
            item.quantity ?? 0,
            item.first_copy_rate ?? 0,
            item.additional_copy_rate ?? 0,
            item.calculated_amount ?? 0,
            item.calculated_amount ?? 0
          ]
        );

        // Deduct Stock
        const newStock = item.current_paper_stock - item.quantity;
        await conn.execute('UPDATE papers SET current_stock = ? WHERE id = ?', [newStock, item.paper_id]);

        // Insert Stock Ledger Entry
        await conn.execute(
          `INSERT INTO stock_ledger 
            (paper_id, transaction_type, reference_id, qty_in, qty_out, balance_qty, remarks)
           VALUES (?, 'JOB_ESTIMATE', ?, 0.00, ?, ?, ?)`,
          [
            item.paper_id,
            jobNumber,
            item.quantity,
            newStock,
            `Job Estimate #${jobNumber}`
          ]
        );
      }

      const [finalJob] = await conn.execute(`
        SELECT 
          j.*,
          c.customer_name,
          c.phone AS customer_phone,
          c.email AS customer_email
        FROM job_details j
        JOIN customers c ON j.customer_id = c.id
        WHERE j.id = ?
      `, [jobDetailId]);

      const [itemsRows] = await conn.execute(
        'SELECT * FROM job_detail_items WHERE job_detail_id = ?',
        [jobDetailId]
      );

      return { ...finalJob[0], items: itemsRows };
    });

    return sendSuccess(res, createdJob, 'Job estimate created successfully', 201);
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/jobs/:id/pdf
 */
async function generateJobPdf(req, res, next) {
  try {
    const { id } = req.params;
    const jobs = await query('SELECT * FROM job_details WHERE id = ?', [id]);
    if (jobs.length === 0) return sendError(res, 'Job estimate not found', [], 404);
    const job = jobs[0];

    const customers = await query('SELECT * FROM customers WHERE id = ?', [job.customer_id]);
    const customer = customers[0] || { customer_name: 'Estimate Customer' };

    const companies = await query('SELECT * FROM companies ORDER BY id ASC LIMIT 1');
    const company = companies[0] || { company_name: 'Printout Company' };

    const items = await query('SELECT * FROM job_detail_items WHERE job_detail_id = ?', [id]);

    const billAdapter = {
      ...job,
      bill_number: job.job_number,
      bill_date: job.job_date,
      cgst_amount: 0,
      sgst_amount: 0,
      igst_amount: 0,
      is_interstate: 0
    };

    const pdfBuffer = await buildPdfBuffer(billAdapter, customer, company, items);

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename=Estimate_${job.job_number}.pdf`);
    return res.send(pdfBuffer);
  } catch (err) { next(err); }
}

/**
 * POST /api/jobs/:id/email
 */
async function emailJobPdf(req, res, next) {
  try {
    const { id } = req.params;
    const jobs = await query('SELECT * FROM job_details WHERE id = ?', [id]);
    if (jobs.length === 0) return sendError(res, 'Job estimate not found', [], 404);
    const job = jobs[0];

    const customers = await query('SELECT * FROM customers WHERE id = ?', [job.customer_id]);
    if (customers.length === 0) return sendError(res, 'Customer not found', [], 404);
    const customer = customers[0];

    if (!customer.email || !customer.email.trim()) {
      return sendError(res, `Customer "${customer.customer_name}" does not have an email address registered in Customer Master.`, [], 400);
    }

    const companies = await query('SELECT * FROM companies ORDER BY id ASC LIMIT 1');
    const company = companies[0] || { company_name: 'Printout Company' };

    const items = await query('SELECT * FROM job_detail_items WHERE job_detail_id = ?', [id]);

    const billAdapter = {
      ...job,
      bill_number: job.job_number,
      bill_date: job.job_date,
      cgst_amount: 0,
      sgst_amount: 0,
      igst_amount: 0,
      is_interstate: 0
    };

    const pdfBuffer = await buildPdfBuffer(billAdapter, customer, company, items);

    await sendInvoiceEmail({
      to: customer.email,
      subject: `Estimate #${job.job_number} - ${company.company_name || 'Printout Billing'}`,
      text: `Dear ${customer.customer_name},

Please find attached your job estimate #${job.job_number} for Rs. ${parseFloat(job.grand_total).toFixed(2)}.

Thank you!`,
      pdfBuffer,
      filename: `Estimate_${job.job_number}.pdf`
    });

    return sendSuccess(res, null, `Job estimate PDF successfully emailed to ${customer.email}`);
  } catch (err) { next(err); }
}

/**
 * POST /api/jobs/:id/print
 */
async function printJob(req, res, next) {
  try {
    const { id } = req.params;

    const settingsRows = await query('SELECT * FROM printer_settings ORDER BY id ASC LIMIT 1');
    if (settingsRows.length === 0 || settingsRows[0].printer_enabled !== 1) {
      return sendError(res, 'Thermal printer is currently DISABLED in Printer Configuration. Enable printer in Settings first.', [], 400);
    }
    const printerSettings = settingsRows[0];

    const jobs = await query('SELECT * FROM job_details WHERE id = ?', [id]);
    if (jobs.length === 0) return sendError(res, 'Job estimate not found', [], 404);
    const job = jobs[0];

    const customers = await query('SELECT * FROM customers WHERE id = ?', [job.customer_id]);
    const customer = customers[0] || { customer_name: 'Estimate Customer' };

    const companies = await query('SELECT * FROM companies ORDER BY id ASC LIMIT 1');
    const company = companies[0] || { company_name: 'Printout Company' };

    const items = await query('SELECT * FROM job_detail_items WHERE job_detail_id = ?', [id]);

    const billAdapter = {
      ...job,
      bill_number: job.job_number,
      bill_date: job.job_date,
      cgst_amount: 0,
      sgst_amount: 0,
      igst_amount: 0,
      is_interstate: 0
    };

    const receiptBuffer = generateThermalReceipt({
      company,
      customer,
      bill: billAdapter,
      items
    });

    await sendToPrinter({
      ip: printerSettings.printer_ip,
      port: printerSettings.printer_port,
      data: receiptBuffer
    });

    return sendSuccess(res, null, `Job Estimate #${job.job_number} sent successfully to printer`);
  } catch (err) { next(err); }
}

module.exports = {
  getJobs,
  getJobById,
  createJob,
  generateJobPdf,
  emailJobPdf,
  printJob
};
