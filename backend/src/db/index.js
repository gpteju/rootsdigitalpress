// CHANGE-2026-09-07: Created MySQL Connection Pool & Database Helper with Transaction support.

const mysql = require('mysql2/promise');
require('dotenv').config();

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '3306', 10),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'printout_billing_db',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  decimalNumbers: true
};

let pool = null;

/**
 * Initializes MySQL pool connection after ensuring database exists.
 */
async function initializeDatabasePool() {
  try {
    // 1. First connect without selecting database to ensure DB exists
    const tempConn = await mysql.createConnection({
      host: dbConfig.host,
      port: dbConfig.port,
      user: dbConfig.user,
      password: dbConfig.password
    });

    await tempConn.query(`CREATE DATABASE IF NOT EXISTS \`${dbConfig.database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`);
    await tempConn.end();

    // 2. Create the main connection pool
    pool = mysql.createPool(dbConfig);
    console.log(`[DB] Connected to MySQL database "${dbConfig.database}" at ${dbConfig.host}:${dbConfig.port}`);
    return pool;
  } catch (err) {
    console.error('[DB] Error initializing database pool:', err.message);
    throw err;
  }
}

/**
 * Gets the active database pool.
 */
function getPool() {
  if (!pool) {
    throw new Error('[DB] Database pool has not been initialized.');
  }
  return pool;
}

/**
 * Executes a parameterized SQL query.
 */
async function query(sql, params = []) {
  const p = getPool();
  const [rows, fields] = await p.execute(sql, params);
  return rows;
}

/**
 * Executes operations inside a MySQL Transaction.
 * @param {Function} callback - Async function receiving the connection context.
 */
async function withTransaction(callback) {
  const p = getPool();
  const connection = await p.getConnection();
  try {
    await connection.beginTransaction();
    const result = await callback(connection);
    await connection.commit();
    return result;
  } catch (error) {
    await connection.rollback();
    console.error('[DB] Transaction rolled back due to error:', error.message);
    throw error;
  } finally {
    connection.release();
  }
}

module.exports = {
  initializeDatabasePool,
  getPool,
  query,
  withTransaction
};
