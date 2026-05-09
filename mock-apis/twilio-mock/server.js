const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

// ─────────────────────────────────────
// HEALTH CHECK
// ─────────────────────────────────────
app.get('/api/twilio/health', (req, res) => {
  const simulateFailure = req.query.simulateFailure === 'true';

  if (simulateFailure) {
    return res.status(503).json({
      status: 'DOWN',
      system: 'Twilio',
      message: 'Twilio service unavailable',
      timestamp: new Date().toISOString()
    });
  }

  res.json({
    status: 'UP',
    system: 'Twilio',
    message: 'Twilio service healthy',
    timestamp: new Date().toISOString()
  });
});

// ─────────────────────────────────────
// SEND SMS
// ─────────────────────────────────────
app.post('/api/twilio/sms', (req, res) => {
  const { correlationId, to, message, type } = req.body;
  const simulateFailure = req.body.simulateFailure === true;

  console.log(`[TWILIO MOCK] SMS | CorrID: ${correlationId} | To: ${to} | Type: ${type}`);

  if (simulateFailure) {
    return res.status(503).json({
      success: false,
      correlationId,
      error: 'SMS_FAILED',
      message: 'Twilio SMS delivery failed'
    });
  }

  res.json({
    success: true,
    correlationId,
    messageId: `SM${Date.now()}`,
    to,
    message,
    type: type || 'ORDER_CONFIRMATION',
    status: 'DELIVERED',
    timestamp: new Date().toISOString()
  });
});

// ─────────────────────────────────────
// SEND ALERT — Circuit Breaker / Admin
// ─────────────────────────────────────
app.post('/api/twilio/alert', (req, res) => {
  const { correlationId, to, alertType, systemName, message } = req.body;

  console.log(`[TWILIO MOCK] Alert | CorrID: ${correlationId} | Type: ${alertType} | System: ${systemName}`);

  res.json({
    success: true,
    correlationId,
    messageId: `SM${Date.now()}`,
    to,
    alertType,
    systemName,
    message,
    status: 'DELIVERED',
    timestamp: new Date().toISOString()
  });
});

// ─────────────────────────────────────
// SERVER START
// ─────────────────────────────────────
const PORT = process.env.PORT || 3002;
app.listen(PORT, () => {
  console.log(`Twilio Mock API running on port ${PORT}`);
  console.log(`Health: http://localhost:${PORT}/api/twilio/health`);
  console.log(`SMS:    http://localhost:${PORT}/api/twilio/sms`);
  console.log(`Alert:  http://localhost:${PORT}/api/twilio/alert`);
});