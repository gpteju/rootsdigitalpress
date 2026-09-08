// CHANGE-2026-09-07: Created automatic MySQL schema initialization & migration runner.

const { getPool } = require('./index');

/**
 * Runs database migrations and automatic table creation.
 */
async function runMigrations() {
  const pool = getPool();
  const conn = await pool.getConnection();

  try {
    console.log('[DB-MIGRATE] Checking and applying database tables...');

    // 1. Schema Migrations Tracking Table
    await conn.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id INT AUTO_INCREMENT PRIMARY KEY,
        version VARCHAR(50) NOT NULL UNIQUE,
        description VARCHAR(255) NOT NULL,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 2. Users Table (Authentication)
    await conn.query(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        username VARCHAR(50) NOT NULL UNIQUE,
        email VARCHAR(100) NOT NULL UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        full_name VARCHAR(100) NOT NULL,
        role VARCHAR(20) NOT NULL DEFAULT 'ADMIN',
        is_active TINYINT(1) NOT NULL DEFAULT 1,
        last_login_at TIMESTAMP NULL DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // Ensure email and last_login_at columns exist if table was created previously
    try {
      await conn.query(`ALTER TABLE users ADD COLUMN email VARCHAR(100) NOT NULL UNIQUE AFTER username`);
    } catch (e) { /* Column already exists */ }
    try {
      await conn.query(`ALTER TABLE users ADD COLUMN last_login_at TIMESTAMP NULL DEFAULT NULL AFTER is_active`);
    } catch (e) { /* Column already exists */ }

    // 3. Company Master
    await conn.query(`
      CREATE TABLE IF NOT EXISTS companies (
        id INT AUTO_INCREMENT PRIMARY KEY,
        company_name VARCHAR(150) NOT NULL,
        address TEXT NOT NULL,
        city VARCHAR(100) NOT NULL,
        state VARCHAR(100) NOT NULL,
        state_code VARCHAR(10) NOT NULL,
        gstin VARCHAR(15) DEFAULT NULL,
        phone VARCHAR(20) NOT NULL,
        email VARCHAR(100) NOT NULL,
        invoice_prefix VARCHAR(10) NOT NULL DEFAULT 'INV-',
        is_active TINYINT(1) NOT NULL DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 4. Customers Master
    await conn.query(`
      CREATE TABLE IF NOT EXISTS customers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        customer_name VARCHAR(150) NOT NULL,
        address TEXT DEFAULT NULL,
        city VARCHAR(100) DEFAULT NULL,
        state VARCHAR(100) NOT NULL,
        state_code VARCHAR(10) NOT NULL,
        gstin VARCHAR(15) DEFAULT NULL,
        phone VARCHAR(20) DEFAULT NULL,
        email VARCHAR(100) DEFAULT NULL,
        credit_limit DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        advance_balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        payment_terms INT NOT NULL DEFAULT 30,
        is_active TINYINT(1) NOT NULL DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 5. Suppliers Master
    await conn.query(`
      CREATE TABLE IF NOT EXISTS suppliers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        supplier_name VARCHAR(150) NOT NULL,
        address TEXT DEFAULT NULL,
        city VARCHAR(100) DEFAULT NULL,
        state VARCHAR(100) NOT NULL,
        state_code VARCHAR(10) NOT NULL,
        gstin VARCHAR(15) DEFAULT NULL,
        phone VARCHAR(20) DEFAULT NULL,
        email VARCHAR(100) DEFAULT NULL,
        payment_terms INT NOT NULL DEFAULT 30,
        is_active TINYINT(1) NOT NULL DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 6. Paper Types
    await conn.query(`
      CREATE TABLE IF NOT EXISTS paper_types (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL UNIQUE,
        description TEXT DEFAULT NULL,
        is_active TINYINT(1) NOT NULL DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 7. Paper GSM
    await conn.query(`
      CREATE TABLE IF NOT EXISTS paper_gsm (
        id INT AUTO_INCREMENT PRIMARY KEY,
        gsm_value INT NOT NULL UNIQUE,
        description TEXT DEFAULT NULL,
        is_active TINYINT(1) NOT NULL DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 8. Paper Sizes
    await conn.query(`
      CREATE TABLE IF NOT EXISTS paper_sizes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(50) NOT NULL UNIQUE,
        description TEXT DEFAULT NULL,
        is_active TINYINT(1) NOT NULL DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 9. Papers (Unified Master)
    await conn.query(`
      CREATE TABLE IF NOT EXISTS papers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        paper_name VARCHAR(150) NOT NULL,
        paper_type_id INT NOT NULL,
        paper_gsm_id INT NOT NULL,
        paper_size_id INT NOT NULL,
        purchase_unit VARCHAR(20) NOT NULL DEFAULT 'Sheet',
        opening_stock DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        current_stock DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        reorder_level DECIMAL(15,2) NOT NULL DEFAULT 100.00,
        is_active TINYINT(1) NOT NULL DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (paper_type_id) REFERENCES paper_types(id),
        FOREIGN KEY (paper_gsm_id) REFERENCES paper_gsm(id),
        FOREIGN KEY (paper_size_id) REFERENCES paper_sizes(id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 10. Printout Types
    await conn.query(`
      CREATE TABLE IF NOT EXISTS printout_types (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL UNIQUE,
        sides VARCHAR(20) NOT NULL DEFAULT 'Single',
        color_mode VARCHAR(20) NOT NULL DEFAULT 'B/W',
        description TEXT DEFAULT NULL,
        is_active TINYINT(1) NOT NULL DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 11. Taxes & Sub Taxes
    await conn.query(`
      CREATE TABLE IF NOT EXISTS taxes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tax_name VARCHAR(100) NOT NULL UNIQUE,
        tax_percentage DECIMAL(5,2) NOT NULL,
        is_active TINYINT(1) NOT NULL DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS tax_sub_taxes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tax_id INT NOT NULL,
        sub_tax_name VARCHAR(50) NOT NULL,
        rate_percentage DECIMAL(5,2) NOT NULL,
        tax_type VARCHAR(30) NOT NULL,
        FOREIGN KEY (tax_id) REFERENCES taxes(id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 12. Rate Master
    await conn.query(`
      CREATE TABLE IF NOT EXISTS rates (
        id INT AUTO_INCREMENT PRIMARY KEY,
        paper_id INT NOT NULL,
        printout_type_id INT NOT NULL,
        first_copy_rate DECIMAL(15,2) NOT NULL,
        additional_copy_rate DECIMAL(15,2) NOT NULL,
        is_active TINYINT(1) NOT NULL DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY unique_paper_printout (paper_id, printout_type_id),
        FOREIGN KEY (paper_id) REFERENCES papers(id),
        FOREIGN KEY (printout_type_id) REFERENCES printout_types(id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 13. Sales Bills & Items
    await conn.query(`
      CREATE TABLE IF NOT EXISTS sales_bills (
        id INT AUTO_INCREMENT PRIMARY KEY,
        bill_number VARCHAR(50) NOT NULL UNIQUE,
        bill_date DATE NOT NULL,
        customer_id INT NOT NULL,
        tax_id INT NOT NULL,
        company_state_snapshot VARCHAR(100) NOT NULL,
        customer_state_snapshot VARCHAR(100) NOT NULL,
        is_interstate TINYINT(1) NOT NULL DEFAULT 0,
        subtotal DECIMAL(15,2) NOT NULL,
        cgst_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        sgst_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        igst_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        grand_total DECIMAL(15,2) NOT NULL,
        paid_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        balance_amount DECIMAL(15,2) NOT NULL,
        status VARCHAR(20) NOT NULL DEFAULT 'UNPAID',
        notes TEXT DEFAULT NULL,
        created_by INT DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers(id),
        FOREIGN KEY (tax_id) REFERENCES taxes(id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS sales_bill_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        sales_bill_id INT NOT NULL,
        paper_id INT NOT NULL,
        printout_type_id INT NOT NULL,
        paper_name_snapshot VARCHAR(150) NOT NULL,
        printout_type_name_snapshot VARCHAR(100) NOT NULL,
        quantity DECIMAL(15,2) NOT NULL,
        first_copy_rate DECIMAL(15,2) NOT NULL,
        additional_copy_rate DECIMAL(15,2) NOT NULL,
        calculated_amount DECIMAL(15,2) NOT NULL,
        tax_percentage DECIMAL(5,2) NOT NULL,
        tax_amount DECIMAL(15,2) NOT NULL,
        total_amount DECIMAL(15,2) NOT NULL,
        FOREIGN KEY (sales_bill_id) REFERENCES sales_bills(id) ON DELETE CASCADE,
        FOREIGN KEY (paper_id) REFERENCES papers(id),
        FOREIGN KEY (printout_type_id) REFERENCES printout_types(id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 14. Customer Payments & Allocations
    await conn.query(`
      CREATE TABLE IF NOT EXISTS customer_payments (
        id INT AUTO_INCREMENT PRIMARY KEY,
        payment_number VARCHAR(50) NOT NULL UNIQUE,
        payment_date DATE NOT NULL,
        customer_id INT NOT NULL,
        amount DECIMAL(15,2) NOT NULL,
        allocated_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        advance_credit_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        payment_mode VARCHAR(30) NOT NULL DEFAULT 'CASH',
        reference_number VARCHAR(100) DEFAULT NULL,
        notes TEXT DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS payment_allocations (
        id INT AUTO_INCREMENT PRIMARY KEY,
        payment_id INT NOT NULL,
        sales_bill_id INT NOT NULL,
        allocated_amount DECIMAL(15,2) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (payment_id) REFERENCES customer_payments(id) ON DELETE CASCADE,
        FOREIGN KEY (sales_bill_id) REFERENCES sales_bills(id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 15. Supplier Purchases & Items
    await conn.query(`
      CREATE TABLE IF NOT EXISTS supplier_purchases (
        id INT AUTO_INCREMENT PRIMARY KEY,
        purchase_number VARCHAR(50) NOT NULL UNIQUE,
        purchase_date DATE NOT NULL,
        supplier_id INT NOT NULL,
        invoice_number VARCHAR(100) DEFAULT NULL,
        subtotal DECIMAL(15,2) NOT NULL,
        cgst_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        sgst_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        igst_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        grand_total DECIMAL(15,2) NOT NULL,
        paid_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        balance_amount DECIMAL(15,2) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS supplier_purchase_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        supplier_purchase_id INT NOT NULL,
        paper_id INT NOT NULL,
        quantity DECIMAL(15,2) NOT NULL,
        rate DECIMAL(15,2) NOT NULL,
        amount DECIMAL(15,2) NOT NULL,
        tax_percentage DECIMAL(5,2) NOT NULL DEFAULT 0.00,
        tax_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        total_amount DECIMAL(15,2) NOT NULL,
        FOREIGN KEY (supplier_purchase_id) REFERENCES supplier_purchases(id) ON DELETE CASCADE,
        FOREIGN KEY (paper_id) REFERENCES papers(id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 16. Stock Ledger
    await conn.query(`
      CREATE TABLE IF NOT EXISTS stock_ledger (
        id INT AUTO_INCREMENT PRIMARY KEY,
        paper_id INT NOT NULL,
        transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        transaction_type VARCHAR(30) NOT NULL,
        reference_id VARCHAR(50) DEFAULT NULL,
        qty_in DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        qty_out DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        balance_qty DECIMAL(15,2) NOT NULL,
        remarks VARCHAR(255) DEFAULT NULL,
        FOREIGN KEY (paper_id) REFERENCES papers(id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 17. Printer Settings
    await conn.query(`
      CREATE TABLE IF NOT EXISTS printer_settings (
        id INT AUTO_INCREMENT PRIMARY KEY,
        printer_enabled TINYINT(1) NOT NULL DEFAULT 0,
        printer_ip VARCHAR(45) NOT NULL DEFAULT '192.168.1.100',
        printer_port INT NOT NULL DEFAULT 9100,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // Insert default printer settings row if empty
    const [existingPrinterSettings] = await conn.query('SELECT COUNT(*) AS cnt FROM printer_settings');
    if (existingPrinterSettings[0].cnt === 0) {
      await conn.query(`
        INSERT INTO printer_settings (printer_enabled, printer_ip, printer_port) 
        VALUES (0, '', 9100)
      `);
    }

    
    // 18. Alter Customer Table for Dual Customer Type (is_estimate)
    try {
      await conn.query(`ALTER TABLE customers ADD COLUMN is_estimate TINYINT(1) NOT NULL DEFAULT 0`);
    } catch (e) {
      // Column may already exist
    }

    // 19. Alter Companies Table for Estimate Numbering Configuration
    try {
      await conn.query(`ALTER TABLE companies ADD COLUMN estimate_prefix VARCHAR(10) NOT NULL DEFAULT 'JOB-'`);
    } catch (e) {}
    try {
      await conn.query(`ALTER TABLE companies ADD COLUMN estimate_current_number INT NOT NULL DEFAULT 0`);
    } catch (e) {}

    // 20. Job Details (Estimate Customer Bills)
    await conn.query(`
      CREATE TABLE IF NOT EXISTS job_details (
        id INT AUTO_INCREMENT PRIMARY KEY,
        job_number VARCHAR(50) NOT NULL UNIQUE,
        job_date DATE NOT NULL,
        customer_id INT NOT NULL,
        subtotal DECIMAL(15,2) NOT NULL,
        grand_total DECIMAL(15,2) NOT NULL,
        notes TEXT DEFAULT NULL,
        created_by INT DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS job_detail_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        job_detail_id INT NOT NULL,
        paper_id INT NOT NULL,
        printout_type_id INT NOT NULL,
        paper_name_snapshot VARCHAR(150) NOT NULL,
        printout_type_name_snapshot VARCHAR(100) NOT NULL,
        quantity DECIMAL(15,2) NOT NULL,
        first_copy_rate DECIMAL(15,2) NOT NULL,
        additional_copy_rate DECIMAL(15,2) NOT NULL,
        calculated_amount DECIMAL(15,2) NOT NULL,
        total_amount DECIMAL(15,2) NOT NULL,
        FOREIGN KEY (job_detail_id) REFERENCES job_details(id) ON DELETE CASCADE,
        FOREIGN KEY (paper_id) REFERENCES papers(id),
        FOREIGN KEY (printout_type_id) REFERENCES printout_types(id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    
    // 21. Alter sales_bills Table for round_off column
    try {
      await conn.query(`ALTER TABLE sales_bills ADD COLUMN round_off DECIMAL(15,2) NOT NULL DEFAULT 0.00 AFTER igst_amount`);
    } catch (e) {
      // Column may already exist
    }

    console.log('[DB-MIGRATE] Database migration completed successfully.');
  } catch (err) {
    console.error('[DB-MIGRATE] Migration failed:', err.message);
    throw err;
  } finally {
    conn.release();
  }
}

module.exports = { runMigrations };
