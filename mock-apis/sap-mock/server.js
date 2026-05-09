const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

// ─────────────────────────────────────
// HEALTH CHECK
// ─────────────────────────────────────
app.get('/api/sap/health', (req, res) => {
  const simulateFailure = req.query.simulateFailure === 'true';
  
  if (simulateFailure) {
    return res.status(503).json({
      status: 'DOWN',
      system: 'SAP',
      message: 'SAP server unavailable',
      timestamp: new Date().toISOString()
    });
  }

  res.json({
    status: 'UP',
    system: 'SAP',
    message: 'SAP system healthy',
    timestamp: new Date().toISOString()
  });
});

// ─────────────────────────────────────
// STOCK DATABASE — DYNAMIC
// ─────────────────────────────────────
const stockData = {
  'Forklift':  { available: 50, warehouse: 'Warehouse-C' },
  'Crane':     { available: 5,  warehouse: 'Warehouse-A' },
  'Excavator': { available: 0,  warehouse: 'Warehouse-B' },
  'Bulldozer': { available: 12, warehouse: 'Warehouse-D' }
};

// ─────────────────────────────────────
// STOCK CHECK — DYNAMIC
// ─────────────────────────────────────
app.get('/api/sap/stock-check', (req, res) => {
  const { item, quantity, correlationId } = req.query;
  const simulateFailure = req.query.simulateFailure === 'true';

  console.log(`[SAP MOCK] Stock Check | Item: ${item} | Qty: ${quantity} | CorrID: ${correlationId}`);

  if (simulateFailure) {
    return res.status(503).json({
      success: false,
      correlationId,
      error: 'SAP_CONNECTION_TIMEOUT',
      message: 'SAP system not responding'
    });
  }

  // Item stock mein hai?
  const stock = stockData[item];

  if (!stock) {
    return res.status(404).json({
      success: false,
      correlationId,
      error: 'ITEM_NOT_FOUND',
      message: `Item '${item}' SAP catalog mein nahi hai`
    });
  }

  // Stock enough hai?
  const requestedQty = parseInt(quantity);
  const isAvailable = stock.available >= requestedQty;

  res.json({
    success: isAvailable,
    correlationId,
    item,
    quantityRequested: requestedQty,
    quantityAvailable: stock.available,
    warehouseLocation: stock.warehouse,
    message: isAvailable
      ? `Stock available — ${stock.warehouse}`
      : `Insufficient stock — only ${stock.available} available`
  });
});
// ─────────────────────────────────────
// CREATE INVOICE
// ─────────────────────────────────────
app.post('/api/sap/create-invoice', (req, res) => {
  const { correlationId, item, quantity, amount, customer } = req.body;
  const simulateFailure = req.body.simulateFailure === true;

  console.log(`[SAP MOCK] Create Invoice | CorrID: ${correlationId} | Customer: ${customer}`);

  if (simulateFailure) {
    return res.status(503).json({
      success: false,
      correlationId,
      error: 'SAP_INVOICE_FAILED',
      message: 'SAP invoice creation failed'
    });
  }

  res.json({
    success: true,
    correlationId,
    invoiceNumber: `INV-${Date.now()}`,
    item,
    quantity,
    amount,
    customer,
    status: 'CREATED',
    message: 'Invoice created successfully'
  });
});

// ─────────────────────────────────────
// CANCEL INVOICE — SAGA COMPENSATION
// ─────────────────────────────────────
app.post('/api/sap/cancel-invoice', (req, res) => {
  const { correlationId, invoiceNumber } = req.body;

  console.log(`[SAP MOCK] Cancel Invoice | CorrID: ${correlationId} | Invoice: ${invoiceNumber}`);

  res.json({
    success: true,
    correlationId,
    invoiceNumber,
    status: 'CANCELLED',
    message: 'Invoice cancelled — SAGA compensation complete'
  });
});

// ─────────────────────────────────────
// SERVER START
// ─────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`SAP Mock API running on port ${PORT}`);
  console.log(`Health: http://localhost:${PORT}/api/sap/health`);
  console.log(`Stock:  http://localhost:${PORT}/api/sap/stock-check`);
});