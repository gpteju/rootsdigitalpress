// CHANGE-2026-09-07: Created Tax Master API router.

const express = require('express');
const router = express.Router();
const controller = require('../controllers/taxController');

router.get('/', controller.getTaxes);
router.get('/:id', controller.getTaxById);
router.post('/', controller.createTax);
router.put('/:id', controller.updateTax);

module.exports = router;
