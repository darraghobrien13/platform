// Shared between api (request validation) and web (form validation + types).
// Bundlers (esbuild, Vite) compile this TypeScript directly: no build step.
import { z } from 'zod';

export const NOTE_MAX_LENGTH = 500;

export const NewNoteSchema = z.object({
  text: z.string().trim().min(1, 'Note cannot be empty').max(NOTE_MAX_LENGTH),
});
export type NewNote = z.infer<typeof NewNoteSchema>;

export type Note = {
  id: number;
  text: string;
  createdAt: string; // ISO 8601
};

export type Health = {
  status: 'ok';
  service: 'api' | 'web';
  version: string;
};
