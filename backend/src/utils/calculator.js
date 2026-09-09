// CHANGE-2026-09-07: Created financial calculation engine using decimal.js for monetary precision.

const Decimal = require('decimal.js');

// Configure Decimal precision and rounding mode (ROUND_HALF_UP is standard for financial calculations)
Decimal.set({ precision: 20, rounding: Decimal.ROUND_HALF_UP });

/**
 * Calculates rate and line item total based on Quantity Q, First Copy Rate X, and Additional Copy Rate Y.
 * Rate Logic:
 * For Q = 1: Amount = X
 * For Q > 1: Amount = X + ((Q - 1) * Y)
 * 
 * @param {number|string} quantity 
 * @param {number|string} firstCopyRate 
 * @param {number|string} additionalCopyRate 
 * @returns {Object} { lineAmount, effectiveRatePerUnit }
 */
function calculateItemAmount(quantity, firstCopyRate, additionalCopyRate) {
  const qty = new Decimal(quantity || 0);
  const firstRate = new Decimal(firstCopyRate || 0);
  const addRate = new Decimal(additionalCopyRate || 0);

  if (qty.lessThanOrEqualTo(0)) {
    return { lineAmount: 0, effectiveRatePerUnit: 0 };
  }

  let lineAmount = new Decimal(0);
  if (qty.equals(1)) {
    lineAmount = firstRate;
  } else {
    // Qty > 1: X + (Qty - 1) * Y
    const remainingQty = qty.minus(1);
    const additionalTotal = remainingQty.times(addRate);
    lineAmount = firstRate.plus(additionalTotal);
  }

  const roundedLineAmount = lineAmount.toDecimalPlaces(2).toNumber();
  const effectiveRate = lineAmount.dividedBy(qty).toDecimalPlaces(2).toNumber();

  return {
    lineAmount: roundedLineAmount,
    effectiveRatePerUnit: effectiveRate
  };
}

/**
 * Evaluates dynamic GST calculation based on Company State, Customer State, and Tax Master parameters.
 * 
 * @param {string} companyState 
 * @param {string} customerState 
 * @param {number|string} totalSubtotal 
 * @param {Object} taxMaster - { taxPercentage, subTaxes: [{ subTaxName, ratePercentage, taxType }] }
 */
function calculateInvoiceTax(companyState, customerState, totalSubtotal, taxMaster, companyStateCode, customerStateCode) {
  const subtotal = new Decimal(totalSubtotal || 0);
  const compCode = (companyStateCode || '').trim().toUpperCase();
  const custCode = (customerStateCode || '').trim().toUpperCase();
  const compState = (companyState || '').trim().toUpperCase();
  const custState = (customerState || '').trim().toUpperCase();

  const isInterstate = (compCode && custCode)
    ? compCode !== custCode
    : compState !== custState;

  let cgstAmount = new Decimal(0);
  let sgstAmount = new Decimal(0);
  let igstAmount = new Decimal(0);
  let totalTaxAmount = new Decimal(0);

  if (!taxMaster || !taxMaster.tax_percentage) {
    const grandTotal = subtotal.toDecimalPlaces(2).toNumber();
    return {
      isInterstate,
      cgstAmount: 0,
      sgstAmount: 0,
      igstAmount: 0,
      totalTaxAmount: 0,
      grandTotal
    };
  }

  const subTaxes = taxMaster.sub_taxes || [];

  if (!isInterstate) {
    // Intra-state: Apply CGST + SGST
    for (const st of subTaxes) {
      const ratePct = new Decimal(st.rate_percentage || 0);
      const taxVal = subtotal.times(ratePct).dividedBy(100);
      if (st.sub_tax_name.toUpperCase().includes('CGST')) {
        cgstAmount = cgstAmount.plus(taxVal);
      } else if (st.sub_tax_name.toUpperCase().includes('SGST')) {
        sgstAmount = sgstAmount.plus(taxVal);
      }
    }
    // Fallback if sub_taxes is empty but total tax_percentage is provided
    if (subTaxes.length === 0 && taxMaster.tax_percentage) {
      const halfRate = new Decimal(taxMaster.tax_percentage).dividedBy(2);
      cgstAmount = subtotal.times(halfRate).dividedBy(100);
      sgstAmount = subtotal.times(halfRate).dividedBy(100);
    }
  } else {
    // Interstate: Apply IGST
    for (const st of subTaxes) {
      if (st.sub_tax_name.toUpperCase().includes('IGST')) {
        const ratePct = new Decimal(st.rate_percentage || 0);
        igstAmount = igstAmount.plus(subtotal.times(ratePct).dividedBy(100));
      }
    }
    if (igstAmount.isZero() && taxMaster.tax_percentage) {
      const fullRate = new Decimal(taxMaster.tax_percentage);
      igstAmount = subtotal.times(fullRate).dividedBy(100);
    }
  }

  totalTaxAmount = cgstAmount.plus(sgstAmount).plus(igstAmount);
  const grandTotal = subtotal.plus(totalTaxAmount);

  return {
    isInterstate,
    cgstAmount: cgstAmount.toDecimalPlaces(2).toNumber(),
    sgstAmount: sgstAmount.toDecimalPlaces(2).toNumber(),
    igstAmount: igstAmount.toDecimalPlaces(2).toNumber(),
    totalTaxAmount: totalTaxAmount.toDecimalPlaces(2).toNumber(),
    grandTotal: grandTotal.toDecimalPlaces(2).toNumber()
  };
}

module.exports = {
  calculateItemAmount,
  calculateInvoiceTax
};
