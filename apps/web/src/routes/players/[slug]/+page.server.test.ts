import { describe, expect, test, vi } from 'vitest';

vi.mock('#lib/api/players', () => ({ getPlayer: vi.fn() }));

import { ApiError } from '#lib/api/client';
import { getPlayer } from '#lib/api/players';
import { load } from './+page.server';

function buildEvent(slug: string) {
	return { params: { slug } } as unknown as Parameters<typeof load>[0];
}

describe('load', () => {
	test('loads the player', async () => {
		const player = {
			id: 1,
			first_name: 'Mateo',
			last_name: 'Rivera',
			slug: 'mateo-rivera',
			country_code: 'ESP',
			current_ranking: 3,
			current_ranking_points: 4500,
			birth_date: '1998-04-02',
			hand: 'right',
			height_cm: 185
		};
		vi.mocked(getPlayer).mockResolvedValue(player);

		const result = await load(buildEvent('mateo-rivera'));

		expect(result).toEqual({ player });
	});

	test('throws a SvelteKit 404 when the player API call returns 404', async () => {
		vi.mocked(getPlayer).mockRejectedValue(
			new ApiError('API request failed: 404 /api/players/unknown', 404)
		);

		await expect(load(buildEvent('unknown'))).rejects.toMatchObject({ status: 404 });
	});

	test('re-throws a non-404 ApiError unchanged', async () => {
		const serverError = new ApiError('API request failed: 500 /api/players/x', 500);
		vi.mocked(getPlayer).mockRejectedValue(serverError);

		await expect(load(buildEvent('x'))).rejects.toBe(serverError);
	});
});
