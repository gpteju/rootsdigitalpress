// CHANGE-2026-09-08: Created PDF Service for generating invoice and job estimate PDF buffers.
// CHANGE-2026-09-10: Redesigned Normal Customer Email Invoice PDF into a professional A4 GST Tax Invoice format.
// CHANGE-2026-09-10: Implemented renderTextWithRupee vector glyph helper to render Indian Rupee (₹ / U+20B9) natively without WinAnsi '(' (0x28) garbled character issue.

const PDFDocument = require('pdfkit');

/**
 * Renders text containing the Indian Rupee symbol (₹ / U+20B9) cleanly.
 * Intercepts '₹' and draws the vector Indian Rupee symbol directly into PDF content stream,
 * avoiding WinAnsi encoding truncation that converts U+20B9 to ASCII '(' (0x28).
 */
function renderTextWithRupee(doc, text, x, y, options = {}) {
  const fontSize = options.fontSize || doc._fontSize || 9;
  const align = options.align || 'left';
  const width = options.width || null;

  if (text === null || text === undefined) return;
  const strText = String(text);
  const parts = strText.split('₹');

  if (parts.length === 1) {
    if (width) {
      doc.text(strText, x, y, { ...options, width, align });
    } else {
      doc.text(strText, x, y, options);
    }
    return;
  }

  const rupeeWidth = fontSize * 0.65;
  let totalWidth = 0;
  parts.forEach((p, idx) => {
    totalWidth += doc.widthOfString(p);
    if (idx < parts.length - 1) totalWidth += rupeeWidth;
  });

  let startX = x;
  if (align === 'right' && width) {
    startX = x + width - totalWidth;
  } else if (align === 'center' && width) {
    startX = x + (width - totalWidth) / 2;
  }

  let currentX = startX;
  parts.forEach((part, idx) => {
    if (part.length > 0) {
      doc.text(part, currentX, y, { lineBreak: false });
      currentX += doc.widthOfString(part);
    }
    if (idx < parts.length - 1) {
      const scale = fontSize / 10;
      doc.save();
      doc.translate(currentX + (0.5 * scale), y + (1.2 * scale));
      doc.scale(scale * 0.85);
      doc.lineWidth(1.3);

      doc.moveTo(0, 1.2).lineTo(5.5, 1.2).stroke();
      doc.moveTo(0, 3.2).lineTo(5.0, 3.2).stroke();
      doc.moveTo(1.4, 1.2).lineTo(1.4, 4.8)
         .bezierCurveTo(4.8, 4.8, 4.8, 3.2, 1.4, 3.2).stroke();
      doc.moveTo(2.0, 4.6).lineTo(5.2, 8.5).stroke();
      doc.restore();

      currentX += rupeeWidth;
    }
  });
}

/**
 * Converts numbers into uppercase Indian Rupee & Paise Words.
 * Example: 4354.20 -> "FOUR THOUSAND THREE HUNDRED FIFTY FOUR RUPEES AND TWENTY PAISE ONLY"
 */
function numberToWords(num) {
  if (num === null || num === undefined || isNaN(num)) return '';
  const n = Math.abs(Number(num));
  const rupees = Math.floor(n);
  const paise = Math.round((n - rupees) * 100);

  const units = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
  const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

  function convertLessThanThousand(val) {
    let str = '';
    if (val >= 100) {
      str += units[Math.floor(val / 100)] + ' Hundred ';
      val %= 100;
    }
    if (val >= 20) {
      str += tens[Math.floor(val / 10)] + ' ';
      val %= 10;
    }
    if (val > 0) {
      str += units[val] + ' ';
    }
    return str.trim();
  }

  function convertRupees(val) {
    if (val === 0) return 'Zero';
    let str = '';

    const crore = Math.floor(val / 10000000);
    val %= 10000000;
    const lakh = Math.floor(val / 100000);
    val %= 100000;
    const thousand = Math.floor(val / 1000);
    val %= 1000;

    if (crore > 0) str += convertLessThanThousand(crore) + ' Crore ';
    if (lakh > 0) str += convertLessThanThousand(lakh) + ' Lakh ';
    if (thousand > 0) str += convertLessThanThousand(thousand) + ' Thousand ';
    if (val > 0) str += convertLessThanThousand(val);

    return str.trim();
  }

  let words = convertRupees(rupees) + ' Rupees';
  if (paise > 0) {
    words += ' And ' + convertLessThanThousand(paise) + ' Paise';
  }
  return words.toUpperCase() + ' ONLY';
}

/**
 * Builds compact receipt PDF buffer for Estimate / Job Customers (is_estimate = true).
 */
function buildEstimatePdfBuffer(bill, customer, company, items) {
  return new Promise((resolve, reject) => {
    try {
      const pageHeight = Math.max(380, 240 + (items.length * 28));
      const doc = new PDFDocument({
        margin: 15,
        size: [283.46, pageHeight]
      });

      const buffers = [];
      doc.on('data', (chunk) => buffers.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(buffers)));

      const margin = 15;
      const col1X = 15;
      const col1Width = 143;
      const col2X = 158;
      const col2Width = 35;
      const col3X = 193;
      const col3Width = 75.46;
      const usableWidth = 253.46;

      const drawLine = () => {
        doc.lineWidth(0.5)
           .moveTo(margin, doc.y)
           .lineTo(margin + usableWidth, doc.y)
           .stroke();
        doc.y += 4;
      };

      doc.font('Helvetica-Bold').fontSize(12).text(company.company_name || 'Printout Company', { align: 'center' });
      doc.font('Helvetica').fontSize(8);
      if (company.address) doc.text(company.address, { align: 'center' });
      const contactInfo = [company.phone ? `Ph: ${company.phone}` : null, company.gstin ? `GSTIN: ${company.gstin}` : null].filter(Boolean).join(' | ');
      if (contactInfo) doc.text(contactInfo, { align: 'center' });
      doc.moveDown(0.4);
      drawLine();

      doc.fontSize(8.5);
      const formattedDate = new Date(bill.bill_date).toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' });
      doc.font('Helvetica-Bold').text(`ESTIMATE JOB: ${bill.bill_number}`, { underline: false });
      doc.font('Helvetica').text(`Date: ${formattedDate}`);
      doc.text(`Customer: ${customer.customer_name || 'Cash'}`);
      if (customer.address) doc.text(`Address: ${customer.address}`);
      if (customer.gstin) doc.text(`GSTIN: ${customer.gstin}`);
      doc.moveDown(0.4);
      drawLine();

      const headerY = doc.y;
      doc.font('Helvetica-Bold').fontSize(8.5);
      doc.text('Printout Type', col1X, headerY, { width: col1Width, align: 'left' });
      doc.text('Qty', col2X, headerY, { width: col2Width, align: 'right' });
      doc.text('Total', col3X, headerY, { width: col3Width, align: 'right' });
      
      const headerHeight = Math.max(
        doc.heightOfString('Printout Type', { width: col1Width }),
        doc.heightOfString('Qty', { width: col2Width }),
        doc.heightOfString('Total', { width: col3Width })
      );
      doc.y = headerY + headerHeight + 3;
      drawLine();

      doc.font('Helvetica').fontSize(8);
      for (const item of items) {
        const itemTitle = item.printout_type_name_snapshot || item.paper_name_snapshot || 'Item';
        const qtyVal = parseFloat(item.quantity).toString();
        const totalVal = `Rs. ${parseFloat(item.calculated_amount || item.total_amount || 0).toFixed(2)}`;

        const startY = doc.y;
        doc.text(itemTitle, col1X, startY, { width: col1Width, align: 'left' });
        doc.text(qtyVal, col2X, startY, { width: col2Width, align: 'right' });
        doc.text(totalVal, col3X, startY, { width: col3Width, align: 'right' });

        const rowHeight = Math.max(
          doc.heightOfString(itemTitle, { width: col1Width }),
          doc.heightOfString(qtyVal, { width: col2Width }),
          doc.heightOfString(totalVal, { width: col3Width })
        );
        doc.y = startY + rowHeight + 3;
      }
      drawLine();

      doc.fontSize(8.5);
      const subtotalY = doc.y;
      doc.font('Helvetica').text('Subtotal', col1X, subtotalY, { width: col1Width, align: 'left' });
      doc.text(`Rs. ${parseFloat(bill.subtotal).toFixed(2)}`, col3X, subtotalY, { width: col3Width, align: 'right' });
      doc.y = subtotalY + 12;

      const grandY = doc.y;
      doc.font('Helvetica-Bold').fontSize(9.5);
      doc.text('Grand Total', col1X, grandY, { width: col1Width, align: 'left' });
      doc.text(`Rs. ${parseFloat(bill.grand_total).toFixed(2)}`, col3X, grandY, { width: col3Width, align: 'right' });
      doc.y = grandY + 14;
      drawLine();

      doc.end();
    } catch (err) {
      reject(err);
    }
  });
}

/**
 * Builds A4 GST Tax Invoice PDF buffer for Normal Customers (is_estimate = false)
 * rendering native vector ₹ symbols cleanly without WinAnsi character encoding issues.
 */
function buildNormalCustomerA4TaxInvoiceBuffer(bill, customer, company, items) {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({
        margin: 25,
        size: 'A4' // 595.28 x 841.89 pt
      });

      const buffers = [];
      doc.on('data', (chunk) => buffers.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(buffers)));

      const margin = 25;
      const pageWidth = 595.28;
      const pageHeight = 841.89;
      const printableWidth = pageWidth - (margin * 2); // 545.28 pt

      // Outer page border
      doc.lineWidth(1)
         .rect(margin, margin, printableWidth, pageHeight - (margin * 2))
         .stroke();

      // 1. Company Header (Y: 25 to 95)
      doc.font('Helvetica-Bold').fontSize(16).text(company.company_name || 'Printout Company', margin, 35, { align: 'center', width: printableWidth });
      doc.font('Helvetica').fontSize(9);
      if (company.address) doc.text(company.address, margin, 56, { align: 'center', width: printableWidth });
      const contactStr = [
        company.phone ? `Ph: ${company.phone}` : null,
        company.email ? `Email: ${company.email}` : null,
        company.gstin ? `GSTIN: ${company.gstin}` : null
      ].filter(Boolean).join('  |  ');
      if (contactStr) doc.text(contactStr, margin, 70, { align: 'center', width: printableWidth });

      // Horizontal Line below Header
      doc.lineWidth(0.75).moveTo(margin, 92).lineTo(margin + printableWidth, 92).stroke();

      // 2. Invoice Type Banner (Y: 92 to 112)
      doc.rect(margin, 92, printableWidth, 20).fillAndStroke('#f0f4f8', '#000000');
      doc.fillColor('#000000').font('Helvetica-Bold').fontSize(10).text('TAX INVOICE', margin + 10, 97);
      doc.font('Helvetica-Bold').fontSize(9).text('ORIGINAL FOR RECIPIENT', margin + printableWidth - 160, 97, { width: 150, align: 'right' });

      // Horizontal Line below Banner
      doc.lineWidth(0.75).moveTo(margin, 112).lineTo(margin + printableWidth, 112).stroke();

      // 3. Two-Column Metadata Box: Billed To vs Invoice Details (Y: 112 to 192)
      const midX = margin + (printableWidth / 2); // 297.64
      doc.moveTo(midX, 112).lineTo(midX, 192).stroke();
      doc.lineWidth(0.75).moveTo(margin, 192).lineTo(margin + printableWidth, 192).stroke();

      // Left Column: Billed To
      const formattedDate = new Date(bill.bill_date).toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' });
      doc.font('Helvetica-Bold').fontSize(9).text('BILLED TO:', margin + 10, 118);
      doc.font('Helvetica-Bold').fontSize(10).text(customer.customer_name || 'Cash Customer', margin + 10, 130);
      doc.font('Helvetica').fontSize(8.5);
      doc.text(`Address : ${customer.address || '—'}`, margin + 10, 144, { width: (printableWidth / 2) - 20 });
      doc.text(`GSTIN   : ${customer.gstin || '—'}`, margin + 10, 162);
      doc.text(`Phone   : ${customer.phone || '—'}`, margin + 10, 174);

      // Right Column: Invoice Details
      doc.font('Helvetica-Bold').fontSize(9.5).text(`Invoice No  : ${bill.bill_number}`, midX + 10, 118);
      doc.font('Helvetica').fontSize(8.5);
      doc.text(`Invoice Date : ${formattedDate}`, midX + 10, 132);
      doc.text(`State / Code : ${customer.state || company.state || 'Tamil Nadu'} (${customer.state_code || '33'})`, midX + 10, 146);
      doc.text('D.C. No.     : —', midX + 10, 160);
      doc.text('Buyer PO Ref : —', midX + 10, 174);

      // 4. Line Items Table Header (Y: 192 to 212)
      const headerY = 192;
      doc.rect(margin, headerY, printableWidth, 20).fillAndStroke('#e2e8f0', '#000000');

      const colHashX = margin;
      const colHashW = 30;

      const colDescX = colHashX + colHashW;
      const colDescW = 235;

      const colHsnX = colDescX + colDescW;
      const colHsnW = 65;

      const colQtyX = colHsnX + colHsnW;
      const colQtyW = 55;

      const colRateX = colQtyX + colQtyW;
      const colRateW = 70;

      const colAmtX = colRateX + colRateW;
      const colAmtW = printableWidth - (colHashW + colDescW + colHsnW + colQtyW + colRateW); // 90.28

      doc.fillColor('#000000').font('Helvetica-Bold').fontSize(8.5);
      doc.text('#', colHashX, headerY + 5, { width: colHashW, align: 'center' });
      doc.text('Product Specification / Description', colDescX + 5, headerY + 5, { width: colDescW - 10, align: 'left' });
      doc.text('HSN/SAC', colHsnX, headerY + 5, { width: colHsnW, align: 'center' });
      doc.text('Qty', colQtyX, headerY + 5, { width: colQtyW - 5, align: 'right' });
      renderTextWithRupee(doc, 'Rate (₹)', colRateX, headerY + 5, { width: colRateW - 5, align: 'right', fontSize: 8.5 });
      renderTextWithRupee(doc, 'Amount (₹)', colAmtX, headerY + 5, { width: colAmtW - 10, align: 'right', fontSize: 8.5 });

      doc.lineWidth(0.75).moveTo(margin, headerY + 20).lineTo(margin + printableWidth, headerY + 20).stroke();

      // Items Table Rows (Y: 212 to 430)
      let currY = headerY + 20;
      doc.font('Helvetica').fontSize(8.5);

      for (let i = 0; i < items.length; i++) {
        const item = items[i];
        const itemTitle = item.printout_type_name_snapshot || item.paper_name_snapshot || item.rate_type || 'Line Item';
        const hsnVal = item.hsn_code || '9988';
        const qtyVal = parseFloat(item.quantity || 1).toString();
        const amtVal = parseFloat(item.calculated_amount || item.total_amount || 0);
        const rateVal = (amtVal / parseFloat(item.quantity || 1)).toFixed(2);

        doc.text((i + 1).toString(), colHashX, currY + 4, { width: colHashW, align: 'center' });
        doc.text(itemTitle, colDescX + 5, currY + 4, { width: colDescW - 10, align: 'left' });
        doc.text(hsnVal, colHsnX, currY + 4, { width: colHsnW, align: 'center' });
        doc.text(qtyVal, colQtyX, currY + 4, { width: colQtyW - 5, align: 'right' });
        renderTextWithRupee(doc, `₹${rateVal}`, colRateX, currY + 4, { width: colRateW - 5, align: 'right', fontSize: 8.5 });
        renderTextWithRupee(doc, `₹${amtVal.toFixed(2)}`, colAmtX, currY + 4, { width: colAmtW - 10, align: 'right', fontSize: 8.5 });

        currY += 22;
      }

      // Vertical Grid Lines for Items Table down to Y = 430
      const tableBottomY = 430;
      doc.lineWidth(0.5);
      doc.moveTo(colDescX, headerY).lineTo(colDescX, tableBottomY).stroke();
      doc.moveTo(colHsnX, headerY).lineTo(colHsnX, tableBottomY).stroke();
      doc.moveTo(colQtyX, headerY).lineTo(colQtyX, tableBottomY).stroke();
      doc.moveTo(colRateX, headerY).lineTo(colRateX, tableBottomY).stroke();
      doc.moveTo(colAmtX, headerY).lineTo(colAmtX, tableBottomY).stroke();

      doc.lineWidth(0.75).moveTo(margin, tableBottomY).lineTo(margin + printableWidth, tableBottomY).stroke();

      // 5. HSN/SAC Tax Summary Table (Y: 430 to 495)
      const taxHeaderY = tableBottomY;
      doc.rect(margin, taxHeaderY, printableWidth, 16).fillAndStroke('#f0f4f8', '#000000');
      doc.fillColor('#000000').font('Helvetica-Bold').fontSize(8.5).text('HSN / SAC TAX SUMMARY', margin + 10, taxHeaderY + 3);

      const taxTableY = taxHeaderY + 16;
      doc.rect(margin, taxTableY, printableWidth, 16).fillAndStroke('#e2e8f0', '#000000');

      const tCol1X = margin;
      const tCol1W = 75;

      const tCol2X = tCol1X + tCol1W;
      const tCol2W = 100;

      const tCol3X = tCol2X + tCol2W;
      const tCol3W = 90;

      const tCol4X = tCol3X + tCol3W;
      const tCol4W = 90;

      const tCol5X = tCol4X + tCol4W;
      const tCol5W = 90;

      const tCol6X = tCol5X + tCol5W;
      const tCol6W = printableWidth - (tCol1W + tCol2W + tCol3W + tCol4W + tCol5W);

      doc.fillColor('#000000').font('Helvetica-Bold').fontSize(8);
      doc.text('HSN/SAC', tCol1X, taxTableY + 4, { width: tCol1W, align: 'center' });
      renderTextWithRupee(doc, 'Taxable Value (₹)', tCol2X, taxTableY + 4, { width: tCol2W - 5, align: 'right', fontSize: 8 });
      renderTextWithRupee(doc, 'CGST (₹)', tCol3X, taxTableY + 4, { width: tCol3W - 5, align: 'right', fontSize: 8 });
      renderTextWithRupee(doc, 'SGST (₹)', tCol4X, taxTableY + 4, { width: tCol4W - 5, align: 'right', fontSize: 8 });
      renderTextWithRupee(doc, 'IGST (₹)', tCol5X, taxTableY + 4, { width: tCol5W - 5, align: 'right', fontSize: 8 });
      renderTextWithRupee(doc, 'Total Tax (₹)', tCol6X, taxTableY + 4, { width: tCol6W - 10, align: 'right', fontSize: 8 });

      const taxRowY = taxTableY + 16;
      const subtotalVal = parseFloat(bill.subtotal || 0);
      const cgstVal = parseFloat(bill.cgst_amount || 0);
      const sgstVal = parseFloat(bill.sgst_amount || 0);
      const igstVal = parseFloat(bill.igst_amount || 0);
      const totalTaxVal = cgstVal + sgstVal + igstVal;

      doc.font('Helvetica').fontSize(8);
      doc.text('9988', tCol1X, taxRowY + 4, { width: tCol1W, align: 'center' });
      renderTextWithRupee(doc, `₹${subtotalVal.toFixed(2)}`, tCol2X, taxRowY + 4, { width: tCol2W - 5, align: 'right', fontSize: 8 });
      renderTextWithRupee(doc, `₹${cgstVal.toFixed(2)}`, tCol3X, taxRowY + 4, { width: tCol3W - 5, align: 'right', fontSize: 8 });
      renderTextWithRupee(doc, `₹${sgstVal.toFixed(2)}`, tCol4X, taxRowY + 4, { width: tCol4W - 5, align: 'right', fontSize: 8 });
      renderTextWithRupee(doc, `₹${igstVal.toFixed(2)}`, tCol5X, taxRowY + 4, { width: tCol5W - 5, align: 'right', fontSize: 8 });
      renderTextWithRupee(doc, `₹${totalTaxVal.toFixed(2)}`, tCol6X, taxRowY + 4, { width: tCol6W - 10, align: 'right', fontSize: 8 });

      const taxBottomY = taxRowY + 20;
      doc.lineWidth(0.5);
      doc.moveTo(tCol2X, taxTableY).lineTo(tCol2X, taxBottomY).stroke();
      doc.moveTo(tCol3X, taxTableY).lineTo(tCol3X, taxBottomY).stroke();
      doc.moveTo(tCol4X, taxTableY).lineTo(tCol4X, taxBottomY).stroke();
      doc.moveTo(tCol5X, taxTableY).lineTo(tCol5X, taxBottomY).stroke();
      doc.moveTo(tCol6X, taxTableY).lineTo(tCol6X, taxBottomY).stroke();
      doc.lineWidth(0.75).moveTo(margin, taxBottomY).lineTo(margin + printableWidth, taxBottomY).stroke();

      // 6. Financial Summary Box (Y: 495 to 600)
      const summaryStartY = taxBottomY + 10;
      const sumLabelX = midX + 20;
      const sumLabelW = 120;
      const sumValX = midX + 140;
      const sumValW = printableWidth - (midX + 140 - margin) - 10;

      doc.font('Helvetica').fontSize(9);
      doc.text('Subtotal (Taxable) :', sumLabelX, summaryStartY, { width: sumLabelW, align: 'left' });
      renderTextWithRupee(doc, `₹${subtotalVal.toFixed(2)}`, sumValX, summaryStartY, { width: sumValW, align: 'right', fontSize: 9 });

      doc.text('Tax Total :', sumLabelX, summaryStartY + 16, { width: sumLabelW, align: 'left' });
      renderTextWithRupee(doc, `₹${totalTaxVal.toFixed(2)}`, sumValX, summaryStartY + 16, { width: sumValW, align: 'right', fontSize: 9 });

      const roundOffVal = parseFloat(bill.round_off || 0);
      const roundSign = roundOffVal >= 0 ? '+' : '';
      doc.text('Round Off :', sumLabelX, summaryStartY + 32, { width: sumLabelW, align: 'left' });
      renderTextWithRupee(doc, `₹${roundSign}${roundOffVal.toFixed(2)}`, sumValX, summaryStartY + 32, { width: sumValW, align: 'right', fontSize: 9 });

      doc.lineWidth(0.5).moveTo(sumLabelX, summaryStartY + 48).lineTo(margin + printableWidth - 10, summaryStartY + 48).stroke();

      doc.font('Helvetica-Bold').fontSize(11);
      doc.text('GRAND TOTAL :', sumLabelX, summaryStartY + 54, { width: sumLabelW, align: 'left' });
      renderTextWithRupee(doc, `₹${parseFloat(bill.grand_total || 0).toFixed(2)}`, sumValX, summaryStartY + 54, { width: sumValW, align: 'right', fontSize: 11 });

      const summaryBottomY = 600;
      doc.lineWidth(0.75).moveTo(margin, summaryBottomY).lineTo(margin + printableWidth, summaryBottomY).stroke();

      // 7. Amount in Words Box (Y: 600 to 635)
      doc.rect(margin, summaryBottomY, printableWidth, 35).fillAndStroke('#fafafa', '#000000');
      doc.fillColor('#000000').font('Helvetica-Bold').fontSize(8).text('AMOUNT IN WORDS:', margin + 10, summaryBottomY + 5);
      doc.font('Helvetica-Bold').fontSize(9).text(numberToWords(bill.grand_total), margin + 10, summaryBottomY + 17, { width: printableWidth - 20 });

      // Horizontal Line below Words
      doc.lineWidth(0.75).moveTo(margin, summaryBottomY + 35).lineTo(margin + printableWidth, summaryBottomY + 35).stroke();

      // 8. Terms & Conditions & Transport Info (Y: 635 to 705)
      const sectionY = summaryBottomY + 35;
      doc.moveTo(midX, sectionY).lineTo(midX, sectionY + 70).stroke();

      // Left: Terms
      doc.font('Helvetica-Bold').fontSize(8.5).text('TERMS & CONDITIONS:', margin + 10, sectionY + 6);
      doc.font('Helvetica').fontSize(7.5);
      doc.text('1. Goods once sold will not be taken back or exchanged.', margin + 10, sectionY + 20);
      doc.text('2. Payment due as per agreed terms.', margin + 10, sectionY + 32);
      doc.text('3. Interest @ 18% p.a. charged on overdue bills.', margin + 10, sectionY + 44);

      // Right: Transport Info
      doc.font('Helvetica-Bold').fontSize(8.5).text('TRANSPORTATION INFO:', midX + 10, sectionY + 6);
      doc.font('Helvetica').fontSize(8);
      doc.text('Transporter : —', midX + 10, sectionY + 20);
      doc.text('Lorry No.   : —', midX + 10, sectionY + 34);
      doc.text('E-Ref No.   : —', midX + 10, sectionY + 48);

      // Horizontal Line below Terms & Transport
      doc.lineWidth(0.75).moveTo(margin, sectionY + 70).lineTo(margin + printableWidth, sectionY + 70).stroke();

      // 9. Signatures Box (Y: 705 to 791.89)
      const sigY = sectionY + 70;
      doc.moveTo(midX, sigY).lineTo(midX, pageHeight - margin).stroke();

      // Left Signature
      doc.font('Helvetica').fontSize(8.5).text("Receiver's Signature", margin + 10, sigY + 55);

      // Right Signature
      doc.font('Helvetica-Bold').fontSize(8.5).text(`For ${company.company_name || 'Printout Company'}`, midX + 10, sigY + 10);
      doc.font('Helvetica').fontSize(8.5).text('Authorised Signatory', midX + 10, sigY + 55);

      // Footer text at bottom inside margin
      doc.font('Helvetica').fontSize(7.5).text(
        `E. & O. E.  |  Subjected to ${company.state || 'Tamil Nadu'} Jurisdiction  |  This is a Computer Generated Tax Invoice`,
        margin,
        pageHeight - margin - 14,
        { align: 'center', width: printableWidth }
      );

      doc.end();
    } catch (err) {
      reject(err);
    }
  });
}

/**
 * Main PDF buffer builder supporting conditional layout:
 * - Estimate / Job Customers (is_estimate = true) -> Compact receipt PDF format
 * - Normal Customers (is_estimate = false) -> Professional A4 GST Tax Invoice format with native vector ₹ symbol rendering
 */
function buildPdfBuffer(bill, customer, company, items) {
  if (customer && (customer.is_estimate === true || customer.is_estimate === 1)) {
    return buildEstimatePdfBuffer(bill, customer, company, items);
  }
  return buildNormalCustomerA4TaxInvoiceBuffer(bill, customer, company, items);
}

module.exports = {
  buildPdfBuffer,
  numberToWords,
  renderTextWithRupee
};
