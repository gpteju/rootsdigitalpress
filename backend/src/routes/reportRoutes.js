// CHANGE-2026-09-07: Created Financial Reporting Engine API router.

const express = require('express');
const router = express.Router();
const controller = require('../controllers/reportController');

router.get('/daily-sales', controller.getDailySalesReport);
router.get('/customer-wise', controller.getCustomerWiseReport);
router.get('/supplier-purchases', controller.getSupplierPurchasesReport);
router.get('/customer-pending', controller.getCustomerPendingReport);
router.get('/customer-aging', controller.getCustomerAgingReport);
router.get('/stock', controller.getStockReport);

module.exports = router;
