import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { App } from '../src/App.tsx';

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('App', () => {
  it('lists notes from the api', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async (input: RequestInfo | URL) => {
        const url = String(input);
        if (url.endsWith('/notes'))
          return json([{ id: 1, text: 'first', createdAt: new Date().toISOString() }]);
        return json({ status: 'ok', service: 'api', version: 'v' });
      }),
    );
    render(<App />);
    expect(await screen.findByText('first')).toBeTruthy();
  });

  it('validates an empty note in the browser, without calling the api', async () => {
    const fetchMock = vi.fn(async () => json([]));
    vi.stubGlobal('fetch', fetchMock);
    render(<App />);
    const callsBefore = fetchMock.mock.calls.length;
    fireEvent.click(screen.getByRole('button', { name: 'Add' }));
    expect(await screen.findByRole('alert')).toBeTruthy();
    expect(fetchMock.mock.calls.length).toBe(callsBefore);
  });
});
