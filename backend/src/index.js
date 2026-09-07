// CHANGE-2026-09-07: Created Express server application entry point with automatic database initialization.

const express = require('express');
const cors = require('cors');
require('dotenv').config();

const { initializeDatabasePool } = require('./db/index');
const { runMigrations } = require('./db/migrate');
const { seedAdminUser } = require('./db/seeders/userSeeder');
const { sendSuccess, sendError } = require('./utils/response');
const { authenticateToken } = require('./middleware/authMiddleware');

const app = express();
const PORT = process.env.PORT || 5000;

// Enable CORS and JSON body parser
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health Check Endpoint (Public)
app.get('/api/health', (req, res) => {
  return sendSuccess(res, { status: 'UP', timestamp: new Date().toISOString() }, 'Printout Billing API Server is running');
});

// Import API Routers
const authRouter = require('./routes/authRoutes');
const companyRouter = require('./routes/companyRoutes');
const customerRouter = require('./routes/customerRoutes');
const supplierRouter = require('./routes/supplierRoutes');
const paperMastersRouter = require('./routes/paperMastersRoutes');
const printoutTypeRouter = require('./routes/printoutTypeRoutes');
const taxRouter = require('./routes/taxRoutes');
const rateRouter = require('./routes/rateRoutes');
const salesBillRouter = require('./routes/salesBillRoutes');
const paymentRouter = require('./routes/paymentRoutes');
const purchaseRouter = require('./routes/purchaseRoutes');
const stockRouter = require('./routes/stockRoutes');
const reportRouter = require('./routes/reportRoutes');
const settingsRouter = require('./routes/settingsRoutes');

// Mount Public Auth Router
app.use('/api/auth', authRouter);

// Apply JWT Authentication Middleware to all Protected Business APIs
app.use('/api/company', authenticateToken, companyRouter);
app.use('/api/customers', authenticateToken, customerRouter);
app.use('/api/suppliers', authenticateToken, supplierRouter);
app.use('/api/paper-types', authenticateToken, paperMastersRouter.paperTypesRouter);
app.use('/api/paper-gsm', authenticateToken, paperMastersRouter.paperGsmRouter);
app.use('/api/paper-sizes', authenticateToken, paperMastersRouter.paperSizesRouter);
app.use('/api/papers', authenticateToken, paperMastersRouter.papersRouter);
app.use('/api/printout-types', authenticateToken, printoutTypeRouter);
app.use('/api/taxes', authenticateToken, taxRouter);
app.use('/api/rates', authenticateToken, rateRouter);
app.use('/api/sales-bills', authenticateToken, salesBillRouter);
app.use('/api/customer-payments', authenticateToken, paymentRouter);
app.use('/api/purchases', authenticateToken, purchaseRouter);
app.use('/api/stock', authenticateToken, stockRouter);
app.use('/api/reports', authenticateToken, reportRouter);
app.use('/api/settings', authenticateToken, settingsRouter);

// Global 404 Route Handler
app.use((req, res) => {
  return sendError(res, `Route ${req.originalUrl} not found`, [], 404);
});

// Global Error Handling Middleware
app.use((err, req, res, next) => {
  console.error('[SERVER ERROR]', err.stack || err);
  return sendError(res, err.message || 'Internal Server Error', [], 500);
});

/**
 * Bootstrap function to start Express server after database initialization.
 */
async function startServer() {
  try {
    // 1. Initialize MySQL DB pool
    await initializeDatabasePool();
    
    // 2. Automatically run migrations / table creations
    await runMigrations();

    // 3. Seed initial administrator user (Idempotent)
    await seedAdminUser();

    // 3. Start listening for incoming REST API requests
    app.listen(PORT, () => {
      console.log(`===================================================`);
      console.log(`🚀 Printout Billing REST API Server running on port ${PORT}`);
      console.log(`   Health Check: http://localhost:${PORT}/api/health`);
      console.log(`===================================================`);
    });
  } catch (err) {
    console.error('Failed to start server:', err.message);
    process.exit(1);
  }
}

startServer();
