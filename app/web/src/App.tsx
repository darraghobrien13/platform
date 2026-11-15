import { type Health, NewNoteSchema, NOTE_MAX_LENGTH, type Note } from '@platform/shared';
import { type FormEvent, useCallback, useEffect, useState } from 'react';
import { api } from './api.ts';

export function App() {
  const [notes, setNotes] = useState<Note[]>([]);
  const [text, setText] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [versions, setVersions] = useState('');

  const load = useCallback(async () => {
    const res = await api.notes.$get();
    if (res.ok) setNotes(await res.json());
    else setError('Could not load notes');
  }, []);

  useEffect(() => {
    load();
    Promise.all([
      fetch('/healthz').then((r) => r.json() as Promise<Health>),
      fetch('/api/healthz').then((r) => r.json() as Promise<Health>),
    ])
      .then(([w, a]) => setVersions(`web ${w.version} · api ${a.version}`))
      .catch(() => setVersions(''));
  }, [load]);

  async function add(e: FormEvent) {
    e.preventDefault();
    const parsed = NewNoteSchema.safeParse({ text }); // same rules as the api
    if (!parsed.success) return setError(parsed.error.issues[0]?.message ?? 'Invalid note');
    setError(null);
    const res = await api.notes.$post({ json: parsed.data });
    if (!res.ok) return setError('Could not save the note');
    setText('');
    await load();
  }

  async function remove(id: number) {
    await api.notes[':id'].$delete({ param: { id: String(id) } });
    await load();
  }

  return (
    <main style={{ maxWidth: 640, margin: '2rem auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1>Notes</h1>
      <form onSubmit={add} style={{ display: 'flex', gap: 8 }}>
        <input
          aria-label="New note"
          value={text}
          maxLength={NOTE_MAX_LENGTH}
          onChange={(e) => setText(e.target.value)}
          placeholder="Write a note…"
          style={{ flex: 1, padding: 8 }}
        />
        <button type="submit">Add</button>
      </form>
      {error && <p role="alert">{error}</p>}
      <ul>
        {notes.map((n) => (
          <li key={n.id}>
            {n.text} <small>{new Date(n.createdAt).toLocaleString()}</small>{' '}
            <button type="button" onClick={() => remove(n.id)} aria-label={`Delete ${n.text}`}>
              ✕
            </button>
          </li>
        ))}
      </ul>
      <footer>
        <small>{versions}</small>
      </footer>
    </main>
  );
}
