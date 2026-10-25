'use strict';

async function request(url, options) {
  const changing = options && options.method !== 'GET';
  const status = document.getElementById('saveStatus');
  if (changing && status) status.textContent = 'Saving…';
  const response = await fetch(url, options);
  const result = await response.json();
  if (!response.ok) throw new Error(result.error || 'The change could not be saved.');
  if (changing) {
    if (status) status.textContent = 'Saved on this Mac';
    window.dispatchEvent(new Event('workspace-changed'));
  }
  return result;
}
const json = (method, body) => ({ method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });

export const api = {
  workspace() { return request('/api/workspace'); },
  history(direction) { return request('/api/history/' + direction, { method: 'POST' }); },
  root() { return request('/api/root'); },
  async canvas(id) { const response = await fetch('/api/canvas/' + encodeURIComponent(id)); return response.json(); },
  todos() { return request('/api/todos'); },
  patchCanvas(id, body) { return request('/api/canvas/' + id, json('PATCH', body)); },
  create(body) { return request('/api/item', json('POST', body)); },
  patch(id, body) { return request('/api/item/' + id, json('PATCH', body)); },
  patchMany(updates) { return request('/api/items', json('PATCH', { updates })); },
  remove(id) { return request('/api/item/' + id, { method: 'DELETE' }); },
  upload(file) { const body = new FormData(); body.append('file', file); return request('/api/upload', { method: 'POST', body }); }
};
