// CHANGE-2026-09-07: Created Customer Payments API router.

const express = require('express');
const router = express.Router();
const controller = require('../controllers/paymentController');

router.get('/', controller.getPayments);
router.get('/pending-bills/:customerId', controller.getCustomerPendingBills);
router.post('/', controller.processPayment);

module.exports = router;
