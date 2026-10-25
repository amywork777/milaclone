// Keep edits dirty until the server acknowledges them, including while in flight.
export function createSaveQueue(write, onChange = () => {}) {
  const pending = new Map();
  let running = null;
  return {
    get hasWork() { return pending.size > 0; },
    set(id, data) {
      pending.set(id, { ...pending.get(id), ...data });
      onChange(true);
    },
    flush() {
      if (running) return running;
      running = Promise.resolve().then(async () => {
        while (pending.size) {
          const [id, data] = pending.entries().next().value;
          await write(id, data);
          // An edit made during the request must be acknowledged separately.
          if (pending.get(id) === data) pending.delete(id);
        }
      }).finally(() => {
        running = null;
        onChange(pending.size > 0);
      });
      return running;
    }
  };
}
