const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

// ─────────────────────────────────────
// HEALTH CHECK
// ─────────────────────────────────────
app.get('/api/stripe/health', (req, res) => {
  const simulateFailure = req.query.simulateFailure === 'true';
  
  if (simulateFailure) {
    return res.status(503).json({
      status: 'DOWN',
      system: 'Stripe',
      message: 'Stripe service unavailable',
      timestamp: new Date().toISOString()
    });
  }

  res.json({
    status: 'UP',
    system: 'Stripe',
    message: 'Stripe service healthy',
    timestamp: new Date().toISOString()
  });
});

// ─────────────────────────────────────
// CHARGE PAYMENT
// ─────────────────────────────────────
app.post('/api/stripe/charge', (req, res) => {
  const { correlationId, amount, currency, customer, description } = req.body;
  const simulateFailure = req.body.simulateFailure === true;

  console.log(`[STRIPE MOCK] Charge | CorrID: ${correlationId} | Amount: ${amount} | Customer: ${customer}`);

  if (simulateFailure) {
    return res.status(402).json({
      success: false,
      correlationId,
      error: 'CARD_DECLINED',
      message: 'Your card was declined'
    });
  }

  res.json({
    success: true,
    correlationId,
    chargeId: `ch_${Date.now()}`,
    amount,
    currency: currency || 'inr',
    customer,
    description,
    status: 'SUCCEEDED',
    message: 'Payment successful'
  });
});

// ─────────────────────────────────────
// REFUND — SAGA COMPENSATION
// ─────────────────────────────────────
app.post('/api/stripe/refund', (req, res) => {
  const { correlationId, chargeId, amount } = req.body;

  console.log(`[STRIPE MOCK] Refund | CorrID: ${correlationId} | ChargeID: ${chargeId}`);

  res.json({
    success: true,
    correlationId,
    refundId: `re_${Date.now()}`,
    chargeId,
    amount,
    status: 'REFUNDED',
    message: 'Refund successful — SAGA compensation complete'
  });
});

// ─────────────────────────────────────
// PAYMENT STATUS CHECK
// ─────────────────────────────────────
app.get('/api/stripe/status/:chargeId', (req, res) => {
  const { chargeId } = req.params;
  const { correlationId } = req.query;

  console.log(`[STRIPE MOCK] Status Check | ChargeID: ${chargeId}`);

  res.json({
    success: true,
    correlationId,
    chargeId,
    status: 'SUCCEEDED',
    message: 'Payment confirmed'
  });
});

// ─────────────────────────────────────
// SERVER START
// ─────────────────────────────────────
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Stripe Mock API running on port ${PORT}`);
  console.log(`Health: http://localhost:${PORT}/api/stripe/health`);
  console.log(`Charge: http://localhost:${PORT}/api/stripe/charge`);
});