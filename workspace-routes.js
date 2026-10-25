'use strict';

const express = require('express');
const fs = require('fs');
const path = require('path');
const { db, stmt, id, rootCanvasId } = require('./db');
const router = express.Router();
const uploadDir = path.join(__dirname, 'public/uploads');
const past = [], future = [];
const snapshot = () => ({ canvases: db.prepare('SELECT * FROM canvases').all(), items: db.prepare('SELECT * FROM items').all() });
const restore = db.transaction(data => {
  db.prepare('DELETE FROM items').run();
  db.prepare('DELETE FROM canvases').run();
  for (const c of data.canvases) stmt.insertCanvas.run(c);
  for (const it of data.items) stmt.insertItem.run(it);
});

router.get('/api/workspace', (req, res) => {
  const data = snapshot();
  res.json({ ...data, items: data.items.map(it => ({ ...it, data: JSON.parse(it.data || '{}') })), rootCanvasId: rootCanvasId(), canUndo: past.length > 0, canRedo: future.length > 0 });
});
router.post('/api/history/:direction', (req, res) => {
  const source = req.params.direction === 'undo' ? past : req.params.direction === 'redo' ? future : null;
  if (!source) return res.status(400).json({ error: 'Unknown history action' });
  if (!source.length) return res.json({ ok: false });
  const target = source === past ? future : past;
  target.push(snapshot()); restore(source.pop());
  res.json({ ok: true, rootCanvasId: rootCanvasId() });
});
router.get('/api/backup', (req, res, next) => {
  try {
    const data = snapshot(), files = {};
    for (const it of data.items) {
      const src = JSON.parse(it.data || '{}').src;
      if (!src || !src.startsWith('/uploads/')) continue;
      const name = src.slice('/uploads/'.length);
      if (!/^[a-zA-Z0-9_.-]+$/.test(name)) throw new Error('Invalid attachment path');
      const file = path.join(uploadDir, name);
      if (fs.existsSync(file)) files[name] = fs.readFileSync(file).toString('base64');
    }
    res.setHeader('Content-Disposition', 'attachment; filename="pinboard-backup.json"');
    res.json({ format: 'pinboard-milaclone', version: 1, rootCanvasId: rootCanvasId(), ...data, files });
  } catch (error) { next(error); }
});

// Keep a reversible in-memory snapshot around successful content mutations.
// Uploads remain on disk so undo never points at a removed attachment.
router.use('/api', (req, res, next) => {
  if (!['POST', 'PATCH', 'DELETE'].includes(req.method) || req.path === '/upload') return next();
  const before = snapshot();
  res.on('finish', () => {
    if (res.statusCode < 200 || res.statusCode >= 300) return;
    if (JSON.stringify(before) === JSON.stringify(snapshot())) return;
    past.push(before); if (past.length > 50) past.shift(); future.length = 0;
  });
  next();
});

module.exports = router;
