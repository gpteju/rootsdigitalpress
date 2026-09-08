// CHANGE-2026-09-07: Created Printer Settings Controller for GET/POST configuration and test printing over TCP.

const { query } = require('../db/index');
const { sendSuccess, sendError } = require('../utils/response');
const { sendToPrinter } = require('../services/thermalPrinterService');

/**
 * GET /api/settings/printer
 * Retrieves current printer configuration.
 */
async function getPrinterSettings(req, res, next) {
  try {
    const rows = await query('SELECT * FROM printer_settings ORDER BY id ASC LIMIT 1');
    if (rows.length === 0) {
      return sendSuccess(res, {
        id: null,
        printer_enabled: 0,
        printer_ip: '',
        printer_port: 9100
      }, 'Printer settings fetched');
    }
    const setting = rows[0];
    return sendSuccess(res, {
      id: setting.id,
      printer_enabled: setting.printer_enabled === 1 || setting.printer_enabled === true ? 1 : 0,
      printer_ip: setting.printer_ip || '',
      printer_port: setting.printer_port || 9100,
      updated_at: setting.updated_at
    }, 'Printer settings fetched successfully');
  } catch (err) { next(err); }
}

/**
 * POST /api/settings/printer
 * Saves or updates printer configuration.
 */
async function updatePrinterSettings(req, res, next) {
  try {
    const { printer_enabled, printer_ip, printer_port } = req.body;

    const isEnabled = (printer_enabled === true || printer_enabled === 1 || printer_enabled === '1' || printer_enabled === 'true') ? 1 : 0;
    const ipStr = (printer_ip || '').toString().trim();
    const portInt = parseInt(printer_port || '9100', 10);

    if (isEnabled === 1) {
      if (!ipStr) {
        return sendError(res, 'Printer IP address is required when Printer is ENABLED.');
      }
      if (isNaN(portInt) || portInt <= 0 || portInt > 65535) {
        return sendError(res, 'Valid Printer TCP Port (1-65535) is required.');
      }
    }

    const rows = await query('SELECT id FROM printer_settings ORDER BY id ASC LIMIT 1');
    if (rows.length > 0) {
      await query(
        'UPDATE printer_settings SET printer_enabled = ?, printer_ip = ?, printer_port = ? WHERE id = ?',
        [isEnabled, ipStr, portInt, rows[0].id]
      );
    } else {
      await query(
        'INSERT INTO printer_settings (printer_enabled, printer_ip, printer_port) VALUES (?, ?, ?)',
        [isEnabled, ipStr, portInt]
      );
    }

    return sendSuccess(res, {
      printer_enabled: isEnabled,
      printer_ip: ipStr,
      printer_port: portInt
    }, 'Printer configuration saved successfully!');
  } catch (err) { next(err); }
}

/**
 * POST /api/settings/printer/test
 * Sends a test receipt to configured thermal printer over TCP.
 */
async function testPrinter(req, res, next) {
  try {
    const rows = await query('SELECT * FROM printer_settings ORDER BY id ASC LIMIT 1');
    if (rows.length === 0 || rows[0].printer_enabled !== 1) {
      return sendError(res, 'Printer is currently DISABLED in configuration. Please enable printer and set a valid IP and Port before testing.');
    }

    const setting = rows[0];
    if (!setting.printer_ip || !setting.printer_ip.trim()) {
      return sendError(res, 'Printer IP address is not configured. Please save a valid Printer IP.');
    }

    const companies = await query('SELECT company_name FROM companies ORDER BY id ASC LIMIT 1');
    const companyName = companies.length > 0 ? companies[0].company_name : 'Printout Company';

    // Format binary test print ESC/POS receipt payload
    const ESC = '\x1B';
    const GS = '\x1D';
    let out = `${ESC}@`; // init
    out += `${ESC}a\x01`; // center align
    out += `${ESC}E\x01`; // bold ON
    out += `${ESC}!\x30`; // font large
    out += `TEST PRINT\n`;
    out += `${ESC}!0`; // font normal
    out += `${companyName}\n`;
    out += `${ESC}E\x00`; // bold OFF
    out += `--------------------------------\n`;
    out += `${ESC}a\x00`; // left align
    out += `Printer Connection OK\n`;
    out += `IP   : ${setting.printer_ip}\n`;
    out += `Port : ${setting.printer_port}\n`;
    out += `Date : ${new Date().toLocaleString('en-IN')}\n`;
    out += `--------------------------------\n`;
    out += `${ESC}a\x01`; // center align
    out += `Test Print Successful\n\n\n`;
    out += `${GS}V\x41\x03`; // paper cut

    const printBuffer = Buffer.from(out, 'binary');

    await sendToPrinter({
      ip: setting.printer_ip,
      port: setting.printer_port,
      data: printBuffer
    });

    return sendSuccess(res, null, `Test print successfully sent to ${setting.printer_ip}:${setting.printer_port}`);
  } catch (err) {
    return sendError(res, `Test print failed: ${err.message}`, [], 500);
  }
}

/**
 * POST /api/settings/printer/print-receipt
 * Accepts base64-encoded ESC/POS raw bytes from the Flutter frontend
 * and relays them to the configured thermal printer via TCP socket.
 * This enables silent direct printing from Flutter Web without any browser print dialog.
 */
async function printReceipt(req, res, next) {
  try {
    const rows = await query('SELECT * FROM printer_settings ORDER BY id ASC LIMIT 1');
    if (rows.length === 0 || rows[0].printer_enabled !== 1) {
      return sendError(res, 'Thermal printer is DISABLED. Please enable printer and configure IP/Port in Printer Settings before printing.');
    }

    const setting = rows[0];
    if (!setting.printer_ip || !setting.printer_ip.trim()) {
      return sendError(res, 'Printer IP address is not configured. Please save a valid Printer IP in Printer Settings.');
    }

    const { bytes_base64 } = req.body;
    if (!bytes_base64) {
      return sendError(res, 'No print data received. Field "bytes_base64" is required.');
    }

    // Decode the base64 ESC/POS bytes from the frontend
    const printBuffer = Buffer.from(bytes_base64, 'base64');

    await sendToPrinter({
      ip: setting.printer_ip,
      port: setting.printer_port || 9100,
      data: printBuffer
    });

    return sendSuccess(res, null, `Receipt printed successfully to ${setting.printer_ip}:${setting.printer_port || 9100}`);
  } catch (err) {
    return sendError(res, `Print failed: ${err.message}`, [], 500);
  }
}

module.exports = {
  getPrinterSettings,
  updatePrinterSettings,
  testPrinter,
  printReceipt
};
