'use strict';

const express = require('express');
const path = require('path');
const { DB_FILE } = require('./db');

const PORT = process.env.PORT || 4321;
const HOST = process.env.HOST || '127.0.0.1';

const app = express();
app.use(express.json({ limit: '5mb' }));
app.use('/uploads', (req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  if (!/\.(png|jpe?g|webp|gif)$/i.test(req.path)) res.setHeader('Content-Disposition', 'attachment');
  next();
});
app.use(express.static(path.join(__dirname, 'public')));
app.use(require('./workspace-routes'));
app.use(require('./routes'));

app.listen(PORT, HOST, () => {
  console.log(`\n  Canvas board running at http://${HOST}:${PORT}`);
  console.log(`  Data stored in ${DB_FILE}\n`);
});
