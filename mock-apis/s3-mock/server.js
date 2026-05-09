const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

// In-memory storage — Mock S3 bucket
const bucket = {};

// ─────────────────────────────────────
// HEALTH CHECK
// ─────────────────────────────────────
app.get('/api/s3/health', (req, res) => {
  const simulateFailure = req.query.simulateFailure === 'true';

  if (simulateFailure) {
    return res.status(503).json({
      status: 'DOWN',
      system: 'S3',
      message: 'S3 service unavailable',
      timestamp: new Date().toISOString()
    });
  }

  res.json({
    status: 'UP',
    system: 'S3',
    message: 'S3 service healthy',
    totalFiles: Object.keys(bucket).length,
    timestamp: new Date().toISOString()
  });
});

// ─────────────────────────────────────
// UPLOAD FILE
// ─────────────────────────────────────
app.post('/api/s3/upload', (req, res) => {
  const { correlationId, fileName, fileType, fileContent, folder } = req.body;
  const simulateFailure = req.body.simulateFailure === true;

  console.log(`[S3 MOCK] Upload | CorrID: ${correlationId} | File: ${fileName}`);

  if (simulateFailure) {
    return res.status(503).json({
      success: false,
      correlationId,
      error: 'S3_UPLOAD_FAILED',
      message: 'S3 upload failed'
    });
  }

  const fileKey = `${folder || 'contracts'}/${correlationId}/${fileName}`;
  const fileUrl = `https://nexusiq-mock-s3.onrender.com/${fileKey}`;

  // Store in memory
  bucket[fileKey] = {
    fileName,
    fileType,
    fileContent,
    fileUrl,
    uploadedAt: new Date().toISOString(),
    correlationId
  };

  res.json({
    success: true,
    correlationId,
    fileKey,
    fileUrl,
    fileName,
    fileType,
    folder: folder || 'contracts',
    status: 'UPLOADED',
    message: 'File uploaded successfully'
  });
});

// ─────────────────────────────────────
// GET FILE
// ─────────────────────────────────────
app.get('/api/s3/file', (req, res) => {
  const { fileKey, correlationId } = req.query;

  console.log(`[S3 MOCK] Get File | CorrID: ${correlationId} | Key: ${fileKey}`);

  const file = bucket[fileKey];

  if (!file) {
    return res.status(404).json({
      success: false,
      correlationId,
      error: 'FILE_NOT_FOUND',
      message: `File not found: ${fileKey}`
    });
  }

  res.json({
    success: true,
    correlationId,
    fileKey,
    fileName: file.fileName,
    fileType: file.fileType,
    fileUrl: file.fileUrl,
    uploadedAt: file.uploadedAt,
    status: 'FOUND'
  });
});

// ─────────────────────────────────────
// DELETE FILE — SAGA COMPENSATION
// ─────────────────────────────────────
app.delete('/api/s3/file', (req, res) => {
  const { fileKey, correlationId } = req.body;

  console.log(`[S3 MOCK] Delete | CorrID: ${correlationId} | Key: ${fileKey}`);

  if (bucket[fileKey]) {
    delete bucket[fileKey];
  }

  res.json({
    success: true,
    correlationId,
    fileKey,
    status: 'DELETED',
    message: 'File deleted — SAGA compensation complete'
  });
});

// ─────────────────────────────────────
// LIST FILES
// ─────────────────────────────────────
app.get('/api/s3/list', (req, res) => {
  const { folder, correlationId } = req.query;

  const files = Object.keys(bucket)
    .filter(key => !folder || key.startsWith(folder))
    .map(key => ({
      fileKey: key,
      fileName: bucket[key].fileName,
      fileUrl: bucket[key].fileUrl,
      uploadedAt: bucket[key].uploadedAt
    }));

  res.json({
    success: true,
    correlationId,
    folder: folder || 'all',
    totalFiles: files.length,
    files
  });
});

// ─────────────────────────────────────
// SERVER START
// ─────────────────────────────────────
const PORT = process.env.PORT || 3003;
app.listen(PORT, () => {
  console.log(`S3 Mock API running on port ${PORT}`);
  console.log(`Health: http://localhost:${PORT}/api/s3/health`);
  console.log(`Upload: http://localhost:${PORT}/api/s3/upload`);
});