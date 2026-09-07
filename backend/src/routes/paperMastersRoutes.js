// CHANGE-2026-09-07: Created Paper Masters API routers.

const express = require('express');
const controller = require('../controllers/paperMastersController');

// Paper Types Router
const paperTypesRouter = express.Router();
paperTypesRouter.get('/', controller.getPaperTypes);
paperTypesRouter.post('/', controller.createPaperType);
paperTypesRouter.put('/:id', controller.updatePaperType);

// Paper GSM Router
const paperGsmRouter = express.Router();
paperGsmRouter.get('/', controller.getPaperGsm);
paperGsmRouter.post('/', controller.createPaperGsm);
paperGsmRouter.put('/:id', controller.updatePaperGsm);

// Paper Sizes Router
const paperSizesRouter = express.Router();
paperSizesRouter.get('/', controller.getPaperSizes);
paperSizesRouter.post('/', controller.createPaperSize);
paperSizesRouter.put('/:id', controller.updatePaperSize);

// Unified Papers Router
const papersRouter = express.Router();
papersRouter.get('/', controller.getAllPapers);
papersRouter.post('/', controller.createPaper);
papersRouter.put('/:id', controller.updatePaper);

module.exports = {
  paperTypesRouter,
  paperGsmRouter,
  paperSizesRouter,
  papersRouter
};
