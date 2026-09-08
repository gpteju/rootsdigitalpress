// CHANGE-2026-09-08: Created PDF Service for generating invoice and job estimate PDF buffers.

const PDFDocument = require('pdfkit');

/**
 * Helper to build PDF Buffer for a Sales Bill or Estimate Job with compact invoice dimensions and precise alignment.
 */
function buildPdfBuffer(bill, customer, company, items) {
  return new Promise((resolve, reject) => {
    try {
      // Calculate dynamic page height to fit items cleanly on compact invoice size
      const pageHeight = Math.max(380, 240 + (items.length * 28));
      const doc = new PDFDocument({
        margin: 15,
        size: [283.46, pageHeight] // 100mm compact invoice width
      });

      const buffers = [];
      doc.on('data', (chunk) => buffers.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(buffers)));

      const margin = 15;
      const col1X = 15;        // Printout Type column (left-aligned)
      const col1Width = 143;   // Printable width for title
      const col2X = 158;       // Qty column
      const col2Width = 35;    // Width for Qty
      const col3X = 193;       // Total column (right-aligned)
      const col3Width = 75.46; // Width for Total
      const usableWidth = 253.46;

      const drawLine = () => {
        doc.lineWidth(0.5)
           .moveTo(margin, doc.y)
           .lineTo(margin + usableWidth, doc.y)
           .stroke();
        doc.y += 4;
      };

      // 1. Company Header (Centered)
      doc.font('Helvetica-Bold').fontSize(12).text(company.company_name || 'Printout Company', { align: 'center' });
      doc.font('Helvetica').fontSize(8);
      if (company.address) doc.text(company.address, { align: 'center' });
      const contactInfo = [company.phone ? `Ph: ${company.phone}` : null, company.gstin ? `GSTIN: ${company.gstin}` : null].filter(Boolean).join(' | ');
      if (contactInfo) doc.text(contactInfo, { align: 'center' });
      doc.moveDown(0.4);
      drawLine();

      // 2. Customer & Bill Info (Left-aligned)
      doc.fontSize(8.5);
      const formattedDate = new Date(bill.bill_date).toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' });
      doc.font('Helvetica-Bold').text(`INVOICE/ESTIMATE: ${bill.bill_number}`, { underline: false });
      doc.font('Helvetica').text(`Date: ${formattedDate}`);
      doc.text(`Customer: ${customer.customer_name || 'Cash'}`);
      if (customer.address) doc.text(`Address: ${customer.address}`);
      if (customer.gstin) doc.text(`GSTIN: ${customer.gstin}`);
      doc.moveDown(0.4);
      drawLine();

      // 3. Line Items Table Header
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

      // 4. Line Items Table Rows
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

      // 5. Subtotal & Tax Breakdown
      doc.fontSize(8.5);
      const subtotalY = doc.y;
      doc.font('Helvetica').text('Subtotal', col1X, subtotalY, { width: col1Width, align: 'left' });
      doc.text(`Rs. ${parseFloat(bill.subtotal).toFixed(2)}`, col3X, subtotalY, { width: col3Width, align: 'right' });
      doc.y = subtotalY + 12;

      const taxPct = bill.is_interstate ? (bill.tax_percentage || 18) : ((bill.tax_percentage || 18) / 2);
      if (bill.is_interstate) {
        const igstY = doc.y;
        doc.text(`IGST (${taxPct}%)`, col1X, igstY, { width: col1Width, align: 'left' });
        doc.text(`Rs. ${parseFloat(bill.igst_amount || 0).toFixed(2)}`, col3X, igstY, { width: col3Width, align: 'right' });
        doc.y = igstY + 12;
      } else {
        const cgstY = doc.y;
        doc.text(`CGST (${taxPct}%)`, col1X, cgstY, { width: col1Width, align: 'left' });
        doc.text(`Rs. ${parseFloat(bill.cgst_amount || 0).toFixed(2)}`, col3X, cgstY, { width: col3Width, align: 'right' });
        doc.y = cgstY + 12;

        const sgstY = doc.y;
        doc.text(`SGST (${taxPct}%)`, col1X, sgstY, { width: col1Width, align: 'left' });
        doc.text(`Rs. ${parseFloat(bill.sgst_amount || 0).toFixed(2)}`, col3X, sgstY, { width: col3Width, align: 'right' });
        doc.y = sgstY + 12;
      }

      
      const roundOffVal = parseFloat(bill.round_off || 0);
      if (roundOffVal !== 0) {
        const roundY = doc.y;
        doc.font('Helvetica').text('Round Off', col1X, roundY, { width: col1Width, align: 'left' });
        const sign = roundOffVal > 0 ? '+' : '';
        doc.text(`Rs. ${sign}${roundOffVal.toFixed(2)}`, col3X, roundY, { width: col3Width, align: 'right' });
        doc.y = roundY + 12;
      }

      drawLine();

      // 6. Grand Total
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

module.exports = {
  buildPdfBuffer
};
