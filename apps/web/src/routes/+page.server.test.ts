import { describe, expect, test, vi } from 'vitest';

vi.mock('#lib/api/tournaments', () => ({ getTournaments: vi.fn() }));

import { getTournaments } from '#lib/api/tournaments';
import { load } from './+page.server';
import type { Tournament } from '#lib/api/types';

function buildTournament(id: number): Tournament {
	return {
		id,
		name: `Tournament ${id}`,
		slug: `tournament-${id}`,
		category: 'atp_250',
		surface: 'hard',
		venue: null
	};
}

describe('load', () => {
	test('returns at most 3 tournaments on success', async () => {
		const tournaments = [1, 2, 3, 4, 5].map(buildTournament);
		vi.mocked(getTournaments).mockResolvedValue(tournaments);

		const result = await load({} as unknown as Parameters<typeof load>[0]);

		expect(result.tournaments).toHaveLength(3);
		expect(result.tournaments).toEqual(tournaments.slice(0, 3));
		expect(result.apiError).toBe(false);
	});

	test('returns an empty list and apiError true when getTournaments rejects', async () => {
		vi.mocked(getTournaments).mockRejectedValue(new Error('network down'));

		const result = await load({} as unknown as Parameters<typeof load>[0]);

		expect(result.tournaments).toEqual([]);
		expect(result.apiError).toBe(true);
	});
});
