// CHANGE-2026-09-07: Created Printer Settings API router.

const express = require('express');
const router = express.Router();
const controller = require('../controllers/settingsController');

router.get('/printer', controller.getPrinterSettings);
router.post('/printer', controller.updatePrinterSettings);
router.post('/printer/test', controller.testPrinter);

module.exports = router;
