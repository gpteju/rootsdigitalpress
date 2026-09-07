// CHANGE-2026-09-07: Created Rate Master API router.

const express = require('express');
const router = express.Router();
const controller = require('../controllers/rateController');

router.get('/', controller.getRates);
router.get('/lookup', controller.lookupRate);
router.post('/', controller.createRate);
router.put('/:id', controller.updateRate);

module.exports = router;
