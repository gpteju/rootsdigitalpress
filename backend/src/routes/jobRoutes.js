// CHANGE-2026-09-08: Created Job Details API router.

const express = require('express');
const router = express.Router();
const controller = require('../controllers/jobController');

router.get('/', controller.getJobs);
router.get('/:id', controller.getJobById);
router.post('/', controller.createJob);
router.get('/:id/pdf', controller.generateJobPdf);
router.post('/:id/email', controller.emailJobPdf);
router.post('/:id/print', controller.printJob);

module.exports = router;
