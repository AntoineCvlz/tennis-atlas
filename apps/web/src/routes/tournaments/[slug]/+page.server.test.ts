import { describe, expect, test, vi } from 'vitest';

vi.mock('#lib/api/tournaments', () => ({
	getTournament: vi.fn(),
	getMatchesForEdition: vi.fn()
}));

import { ApiError } from '#lib/api/client';
import { getTournament, getMatchesForEdition } from '#lib/api/tournaments';
import { load } from './+page.server';

function buildEvent(slug: string) {
	return { params: { slug } } as unknown as Parameters<typeof load>[0];
}

describe('load', () => {
	test('loads the tournament and its latest edition matches', async () => {
		const tournament = {
			id: 1,
			name: 'Roland Garros',
			slug: 'roland-garros',
			category: 'grand_slam',
			surface: 'clay',
			venue: null,
			description: null,
			logo_url: null,
			hero_image_url: null,
			editions: [
				{ id: 1, year: 2025, start_date: '2025-05-25', end_date: '2025-06-08', status: 'completed' }
			]
		};
		vi.mocked(getTournament).mockResolvedValue(tournament);
		vi.mocked(getMatchesForEdition).mockResolvedValue([]);

		const result = await load(buildEvent('roland-garros'));

		expect(getMatchesForEdition).toHaveBeenCalledWith('roland-garros', 2025);
		expect(result).toEqual({ tournament, edition: tournament.editions[0], matches: [] });
	});

	test('returns an empty match list without calling getMatchesForEdition when there are no editions', async () => {
		const tournament = {
			id: 1,
			name: 'New Tournament',
			slug: 'new-tournament',
			category: 'atp_250',
			surface: 'hard',
			venue: null,
			description: null,
			logo_url: null,
			hero_image_url: null,
			editions: []
		};
		vi.mocked(getTournament).mockResolvedValue(tournament);

		const result = await load(buildEvent('new-tournament'));

		expect(getMatchesForEdition).not.toHaveBeenCalled();
		expect(result).toEqual({ tournament, edition: null, matches: [] });
	});

	test('throws a SvelteKit 404 when the tournament API call returns 404', async () => {
		vi.mocked(getTournament).mockRejectedValue(
			new ApiError('API request failed: 404 /api/tournaments/unknown', 404)
		);

		await expect(load(buildEvent('unknown'))).rejects.toMatchObject({ status: 404 });
	});

	test('re-throws a non-404 ApiError unchanged', async () => {
		const serverError = new ApiError('API request failed: 500 /api/tournaments/x', 500);
		vi.mocked(getTournament).mockRejectedValue(serverError);

		await expect(load(buildEvent('x'))).rejects.toBe(serverError);
	});
});
