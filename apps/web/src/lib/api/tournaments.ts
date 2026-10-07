import { apiFetch } from './client';
import type { Tournament, TournamentDetail, Match, PageMeta } from './types';

export async function getTournaments(): Promise<Tournament[]> {
	const { data } = await apiFetch<{ data: Tournament[] }>('/api/tournaments');
	return data;
}

export async function listTournaments(params: {
	surface?: string;
	category?: string;
	page?: number;
}): Promise<{ tournaments: Tournament[]; meta: PageMeta }> {
	const query = new URLSearchParams();
	if (params.surface) query.set('surface', params.surface);
	if (params.category) query.set('category', params.category);
	if (params.page) query.set('page', String(params.page));

	const { data, meta } = await apiFetch<{ data: Tournament[]; meta: PageMeta }>(
		`/api/tournaments?${query.toString()}`
	);
	return { tournaments: data, meta };
}

export async function getTournament(slug: string): Promise<TournamentDetail> {
	const { data } = await apiFetch<{ data: TournamentDetail }>(`/api/tournaments/${slug}`);
	return data;
}

export async function getMatchesForEdition(slug: string, year: number): Promise<Match[]> {
	const { data } = await apiFetch<{ data: Match[] }>(
		`/api/tournaments/${slug}/editions/${year}/matches?page_size=100`
	);
	return data;
}
