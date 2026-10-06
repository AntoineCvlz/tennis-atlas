import { apiFetch } from './client';
import type { Tournament } from './types';

export async function getTournaments(): Promise<Tournament[]> {
	const { data } = await apiFetch<{ data: Tournament[] }>('/api/tournaments');
	return data;
}
