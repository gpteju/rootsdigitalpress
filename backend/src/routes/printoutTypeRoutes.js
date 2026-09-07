// CHANGE-2026-09-07: Created Printout Type Master API router.

const express = require('express');
const router = express.Router();
const controller = require('../controllers/printoutTypeController');

router.get('/', controller.getPrintoutTypes);
router.post('/', controller.createPrintoutType);
router.put('/:id', controller.updatePrintoutType);

module.exports = router;
