// CHANGE-2026-09-07: Created Company Master API router.

const express = require('express');
const router = express.Router();
const companyController = require('../controllers/companyController');

router.get('/', companyController.getCompany);
router.post('/', companyController.saveCompany);
router.put('/', companyController.saveCompany);

module.exports = router;
