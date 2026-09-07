// CHANGE-2026-09-07: Created Idempotent User Database Seeder for initial Administrator account.

const bcrypt = require('bcryptjs');
const { getPool } = require('../index');

/**
 * Idempotently seeds the initial administrator user from environment variables.
 * Safe to execute repeatedly without duplicating users or resetting existing passwords.
 */
async function seedAdminUser() {
  const pool = getPool();
  const conn = await pool.getConnection();

  try {
    const username = (process.env.SEED_ADMIN_USERNAME || 'admin').trim();
    const email = (process.env.SEED_ADMIN_EMAIL || 'admin@printoutbilling.com').trim();
    const password = process.env.SEED_ADMIN_PASSWORD || 'Admin@123456';
    const fullName = (process.env.SEED_ADMIN_NAME || 'Administrator').trim();

    if (!password || password.trim().length === 0) {
      console.warn('[DB-SEEDER] Skipping admin seed: SEED_ADMIN_PASSWORD environment variable is empty.');
      return;
    }

    // Check if user with username or email already exists
    const [existing] = await conn.query('SELECT COUNT(*) AS cnt FROM users WHERE username = ? OR email = ?', [username, email]);

    if (existing[0].cnt > 0) {
      console.log(`[DB-SEEDER] Initial administrator user ("${username}") already exists. Skipping seed.`);
      return;
    }

    // Hash password with bcrypt
    const passwordHash = await bcrypt.hash(password, 10);

    // Insert Initial Administrator Account
    await conn.query(
      `INSERT INTO users (username, email, password_hash, full_name, role, is_active)
       VALUES (?, ?, ?, ?, 'ADMIN', 1)`,
      [username, email, passwordHash, fullName]
    );

    console.log(`[DB-SEEDER] Initial administrator user successfully created! Username: "${username}", Email: "${email}".`);
  } catch (err) {
    console.error('[DB-SEEDER] Admin user seeding failed:', err.message);
    throw err;
  } finally {
    conn.release();
  }
}

module.exports = { seedAdminUser };
