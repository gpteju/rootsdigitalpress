// CHANGE-2026-09-07: Created Sales Billing Engine API router.

const express = require('express');
const router = express.Router();
const controller = require('../controllers/salesBillController');

router.get('/', controller.getSalesBills);
router.get('/:id', controller.getSalesBillById);
router.post('/', controller.createSalesBill);
router.get('/:id/pdf', controller.generateBillPdf);
router.post('/:id/email', controller.emailBillPdf);
router.post('/:id/print', controller.printSalesBill);

module.exports = router;
