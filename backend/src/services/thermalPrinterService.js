// CHANGE-2026-09-07: Created 3-inch ESC/POS Thermal Printer Service with TCP socket communication and text wrapping.

const net = require('net');

/**
 * Standard ESC/POS Command Constants
 */
const ESC = '\x1B';
const GS = '\x1D';

const COMMANDS = {
  INIT: `${ESC}@`,                      // Initialize printer
  ALIGN_CENTER: `${ESC}a\x01`,          // Center alignment
  ALIGN_LEFT: `${ESC}a\x00`,            // Left alignment
  ALIGN_RIGHT: `${ESC}a\x02`,           // Right alignment
  BOLD_ON: `${ESC}E\x01`,               // Bold mode ON
  BOLD_OFF: `${ESC}E\x00`,              // Bold mode OFF
  FONT_NORMAL: `${ESC}!0`,             // Normal font size
  FONT_LARGE: `${ESC}!\x30`,           // Double height & width font
  CUT_PAPER: `${GS}V\x41\x03`,          // Full paper cut
  FEED_LINES: (n) => `${ESC}d${String.fromCharCode(n)}`
};

/**
 * Wraps text into lines of specified maximum width.
 * @param {string} text 
 * @param {number} maxLen 
 * @returns {string[]}
 */
function wrapText(text, maxLen) {
  if (!text) return [''];
  const words = text.split(' ');
  const lines = [];
  let currentLine = '';

  for (const word of words) {
    if (currentLine.length === 0) {
      if (word.length > maxLen) {
        // Break long word forcefully
        let remaining = word;
        while (remaining.length > maxLen) {
          lines.push(remaining.substring(0, maxLen));
          remaining = remaining.substring(maxLen);
        }
        currentLine = remaining;
      } else {
        currentLine = word;
      }
    } else if (currentLine.length + 1 + word.length <= maxLen) {
      currentLine += ` ${word}`;
    } else {
      lines.push(currentLine);
      if (word.length > maxLen) {
        let remaining = word;
        while (remaining.length > maxLen) {
          lines.push(remaining.substring(0, maxLen));
          remaining = remaining.substring(maxLen);
        }
        currentLine = remaining;
      } else {
        currentLine = word;
      }
    }
  }
  if (currentLine.length > 0) {
    lines.push(currentLine);
  }
  return lines.length === 0 ? [''] : lines;
}

/**
 * Formats a 3-inch (32-character width) thermal receipt.
 * @param {Object} billData 
 * @returns {Buffer} Raw binary ESC/POS buffer ready for TCP transmission
 */
function generateThermalReceipt(billData) {
  const { company, customer, bill, items } = billData;
  const width = 32;
  const col1Width = 17; // Printout Type column
  const col2Width = 5;  // Qty column
  const col3Width = 10; // Total column

  const lineDivider = '-'.repeat(width) + '\n';
  let out = '';

  // Initialize Printer
  out += COMMANDS.INIT;

  // 1. COMPANY HEADER (Centered)
  out += COMMANDS.ALIGN_CENTER;
  out += COMMANDS.BOLD_ON;
  out += COMMANDS.FONT_NORMAL;
  out += `${company.company_name || 'COMPANY NAME'}\n`;
  out += COMMANDS.BOLD_OFF;

  if (company.address) out += `${company.address}\n`;
  if (company.city || company.state) out += `${[company.city, company.state].filter(Boolean).join(', ')}\n`;
  if (company.phone) out += `Phone: ${company.phone}\n`;
  if (company.gstin) out += `GSTIN: ${company.gstin}\n`;
  out += lineDivider;

  // 2. CUSTOMER & BILL DETAILS (Left-aligned)
  out += COMMANDS.ALIGN_LEFT;
  out += `Customer : ${customer.customer_name || 'Cash'}\n`;
  if (customer.address) out += `Address  : ${customer.address}\n`;
  if (customer.gstin) out += `GST No   : ${customer.gstin}\n`;
  out += `Bill No  : ${bill.bill_number}\n`;
  const formattedDate = new Date(bill.bill_date).toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' });
  out += `Date     : ${formattedDate}\n`;
  out += lineDivider;

  // 3. BILL LINE ITEMS
  // Column Headers: "Printout Type" (17) | "Qty" (5) | "Total" (10)
  const headerCol1 = 'Printout Type'.padEnd(col1Width);
  const headerCol2 = 'Qty'.padStart(col2Width);
  const headerCol3 = 'Total'.padStart(col3Width);
  out += COMMANDS.BOLD_ON;
  out += `${headerCol1}${headerCol2}${headerCol3}\n`;
  out += COMMANDS.BOLD_OFF;
  out += lineDivider;

  for (const item of items) {
    let printoutName = item.paper_name_snapshot || item.printout_type_name_snapshot || 'Item';
    if (item.job_name && item.job_name.trim()) {
      printoutName += ` (${item.job_name.trim()})`;
    }
    const qtyStr = parseFloat(item.quantity).toString().padStart(col2Width);
    const totalStr = parseFloat(item.calculated_amount || item.total_amount || 0).toFixed(2).padStart(col3Width);

    const wrappedName = wrapText(printoutName, col1Width);

    // Line 1: first wrapped name line + Qty + Total
    const line1Name = wrappedName[0].padEnd(col1Width);
    out += `${line1Name}${qtyStr}${totalStr}\n`;

    // Subsequent lines for long printout type names (Qty & Total columns remain blank)
    for (let i = 1; i < wrappedName.length; i++) {
      const lineName = wrappedName[i].padEnd(col1Width);
      out += `${lineName}${' '.repeat(col2Width + col3Width)}\n`;
    }
  }

  out += lineDivider;

  // 4. SUBTOTAL
  const subtotalLabel = 'Subtotal'.padEnd(20);
  const subtotalVal = `Rs. ${parseFloat(bill.subtotal).toFixed(2)}`.padStart(12);
  out += `${subtotalLabel}${subtotalVal}\n`;

  // 5. TAX DETAILS
  const taxPct = bill.is_interstate ? (bill.tax_percentage || 18) : ((bill.tax_percentage || 18) / 2);
  if (bill.is_interstate) {
    const igstLabel = `IGST (${taxPct}%)`.padEnd(20);
    const igstVal = `Rs. ${parseFloat(bill.igst_amount || 0).toFixed(2)}`.padStart(12);
    out += `${igstLabel}${igstVal}\n`;
  } else {
    const cgstLabel = `CGST (${taxPct}%)`.padEnd(20);
    const cgstVal = `Rs. ${parseFloat(bill.cgst_amount || 0).toFixed(2)}`.padStart(12);
    out += `${cgstLabel}${cgstVal}\n`;

    const sgstLabel = `SGST (${taxPct}%)`.padEnd(20);
    const sgstVal = `Rs. ${parseFloat(bill.sgst_amount || 0).toFixed(2)}`.padStart(12);
    out += `${sgstLabel}${sgstVal}\n`;
  }

    const roundOffVal = parseFloat(bill.round_off || 0);
  if (roundOffVal !== 0) {
    const roundOffLabel = 'Round Off'.padEnd(20);
    const sign = roundOffVal > 0 ? '+' : '';
    const roundOffValStr = `Rs. ${sign}${roundOffVal.toFixed(2)}`.padStart(12);
    out += `${roundOffLabel}${roundOffValStr}
`;
  }
  out += lineDivider;

  // 6. GRAND TOTAL
  out += COMMANDS.BOLD_ON;
  const grandLabel = 'Grand Total'.padEnd(18);
  const grandVal = `Rs. ${parseFloat(bill.grand_total).toFixed(2)}`.padStart(14);
  out += `${grandLabel}${grandVal}\n`;
  out += COMMANDS.BOLD_OFF;
  out += lineDivider;

  // Footer & Paper Cut
  out += COMMANDS.ALIGN_CENTER;
  out += 'Thank you for your business!\n\n\n';
  out += COMMANDS.CUT_PAPER;

  return Buffer.from(out, 'binary');
}

/**
 * Sends binary ESC/POS data to a network thermal printer over a TCP socket.
 * @param {Object} params
 * @param {string} params.ip - Printer IP address
 * @param {number} params.port - Printer TCP port (default 9100)
 * @param {Buffer} params.data - Binary print payload
 * @returns {Promise<boolean>}
 */
function sendToPrinter({ ip, port, data }) {
  return new Promise((resolve, reject) => {
    if (!ip || !ip.trim()) {
      return reject(new Error('Printer IP address is required and cannot be empty.'));
    }
    const targetPort = parseInt(port || 9100, 10);
    if (isNaN(targetPort) || targetPort <= 0 || targetPort > 65535) {
      return reject(new Error(`Invalid printer port number "${port}".`));
    }

    const socket = new net.Socket();
    let isSettled = false;

    socket.setTimeout(5000); // 5 second timeout

    socket.connect(targetPort, ip.trim(), () => {
      socket.write(data, () => {
        socket.end();
        if (!isSettled) {
          isSettled = true;
          resolve(true);
        }
      });
    });

    socket.on('timeout', () => {
      socket.destroy();
      if (!isSettled) {
        isSettled = true;
        reject(new Error(`Connection to printer at ${ip}:${targetPort} timed out (5s). Ensure printer is ON and reachable on network.`));
      }
    });

    socket.on('error', (err) => {
      socket.destroy();
      if (!isSettled) {
        isSettled = true;
        reject(new Error(`Failed to connect to printer at ${ip}:${targetPort}: ${err.message}`));
      }
    });
  });
}

module.exports = {
  generateThermalReceipt,
  sendToPrinter
};
