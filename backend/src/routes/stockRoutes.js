// CHANGE-2026-09-07: Created Stock Ledger API router.

const express = require('express');
const router = express.Router();
const controller = require('../controllers/stockController');

router.get('/summary', controller.getStockSummary);
router.get('/ledger', controller.getStockLedger);
router.post('/adjust', controller.adjustStock);

module.exports = router;
