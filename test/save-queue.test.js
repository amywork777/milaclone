const test = require('node:test');
const assert = require('node:assert/strict');
const load = () => import('../public/js/save-queue.mjs');

test('edits remain dirty throughout an in-flight save', async () => {
  const { createSaveQueue } = await load();
  let acknowledge;
  const queue = createSaveQueue(() => new Promise(resolve => { acknowledge = resolve; }));
  queue.set('note', { title: 'Keep me' });
  const saving = queue.flush();
  await Promise.resolve();
  assert.equal(queue.hasWork, true);
  acknowledge();
  await saving;
  assert.equal(queue.hasWork, false);
});

test('rapid edits preserve every field and changes made during a request', async () => {
  const { createSaveQueue } = await load();
  const writes = [];
  let acknowledge;
  const queue = createSaveQueue(async (id, data) => {
    writes.push(data);
    if (writes.length === 1) await new Promise(resolve => { acknowledge = resolve; });
  });
  queue.set('note', { title: 'Title' });
  queue.set('note', { body: 'First' });
  const saving = queue.flush();
  await Promise.resolve();
  queue.set('note', { body: 'Latest' });
  acknowledge();
  await saving;
  assert.deepEqual(writes, [{ title: 'Title', body: 'First' }, { title: 'Title', body: 'Latest' }]);
  assert.equal(queue.hasWork, false);
});

test('failed saves remain dirty and can be retried without losing newer edits', async () => {
  const { createSaveQueue } = await load();
  let fail = true;
  const writes = [];
  const queue = createSaveQueue(async (id, data) => {
    if (fail) throw new Error('offline');
    writes.push(data);
  });
  queue.set('note', { title: 'Title' });
  await assert.rejects(queue.flush(), /offline/);
  assert.equal(queue.hasWork, true);
  queue.set('note', { body: 'Body' });
  fail = false;
  await queue.flush();
  assert.deepEqual(writes, [{ title: 'Title', body: 'Body' }]);
  assert.equal(queue.hasWork, false);
});
