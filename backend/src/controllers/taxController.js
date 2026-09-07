// CHANGE-2026-09-07: Created Tax Master controller for taxes and dynamic sub-taxes.

const { query, withTransaction } = require('../db/index');
const { sendSuccess, sendError } = require('../utils/response');

async function getTaxes(req, res, next) {
  try {
    const taxes = await query('SELECT * FROM taxes ORDER BY tax_name ASC');
    for (const tax of taxes) {
      const subTaxes = await query('SELECT * FROM tax_sub_taxes WHERE tax_id = ?', [tax.id]);
      tax.sub_taxes = subTaxes;
    }
    return sendSuccess(res, taxes, 'Tax master fetched successfully');
  } catch (err) { next(err); }
}

async function getTaxById(req, res, next) {
  try {
    const { id } = req.params;
    const taxes = await query('SELECT * FROM taxes WHERE id = ?', [id]);
    if (taxes.length === 0) return sendError(res, 'Tax master record not found', [], 404);
    const tax = taxes[0];
    tax.sub_taxes = await query('SELECT * FROM tax_sub_taxes WHERE tax_id = ?', [id]);
    return sendSuccess(res, tax, 'Tax master details fetched successfully');
  } catch (err) { next(err); }
}

async function createTax(req, res, next) {
  try {
    const { tax_name, tax_percentage, sub_taxes } = req.body;
    if (!tax_name || tax_percentage === undefined) {
      return sendError(res, 'tax_name and tax_percentage are required');
    }

    const createdTax = await withTransaction(async (conn) => {
      const [result] = await conn.execute(
        'INSERT INTO taxes (tax_name, tax_percentage, is_active) VALUES (?, ?, 1)',
        [tax_name, tax_percentage]
      );
      const taxId = result.insertId;

      if (Array.isArray(sub_taxes)) {
        for (const st of sub_taxes) {
          await conn.execute(
            'INSERT INTO tax_sub_taxes (tax_id, sub_tax_name, rate_percentage, tax_type) VALUES (?, ?, ?, ?)',
            [taxId, st.sub_tax_name, st.rate_percentage, st.tax_type || 'INTRA_STATE']
          );
        }
      }

      const [taxRows] = await conn.execute('SELECT * FROM taxes WHERE id = ?', [taxId]);
      const [subRows] = await conn.execute('SELECT * FROM tax_sub_taxes WHERE tax_id = ?', [taxId]);
      return { ...taxRows[0], sub_taxes: subRows };
    });

    return sendSuccess(res, createdTax, 'Tax master created successfully', 201);
  } catch (err) { next(err); }
}

async function updateTax(req, res, next) {
  try {
    const { id } = req.params;
    const { tax_name, tax_percentage, is_active, sub_taxes } = req.body;

    const updatedTax = await withTransaction(async (conn) => {
      await conn.execute(
        'UPDATE taxes SET tax_name = ?, tax_percentage = ?, is_active = ? WHERE id = ?',
        [tax_name, tax_percentage, is_active !== undefined ? is_active : 1, id]
      );

      if (Array.isArray(sub_taxes)) {
        await conn.execute('DELETE FROM tax_sub_taxes WHERE tax_id = ?', [id]);
        for (const st of sub_taxes) {
          await conn.execute(
            'INSERT INTO tax_sub_taxes (tax_id, sub_tax_name, rate_percentage, tax_type) VALUES (?, ?, ?, ?)',
            [id, st.sub_tax_name, st.rate_percentage, st.tax_type || 'INTRA_STATE']
          );
        }
      }

      const [taxRows] = await conn.execute('SELECT * FROM taxes WHERE id = ?', [id]);
      const [subRows] = await conn.execute('SELECT * FROM tax_sub_taxes WHERE tax_id = ?', [id]);
      return { ...taxRows[0], sub_taxes: subRows };
    });

    return sendSuccess(res, updatedTax, 'Tax master updated successfully');
  } catch (err) { next(err); }
}

module.exports = {
  getTaxes,
  getTaxById,
  createTax,
  updateTax
};
