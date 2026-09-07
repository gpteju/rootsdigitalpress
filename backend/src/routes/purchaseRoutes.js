// CHANGE-2026-09-07: Created Supplier Purchases API router.

const express = require('express');
const router = express.Router();
const controller = require('../controllers/purchaseController');

router.get('/', controller.getPurchases);
router.get('/:id', controller.getPurchaseById);
router.post('/', controller.createPurchase);

module.exports = router;
