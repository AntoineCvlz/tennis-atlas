import { describe, expect, test, vi } from 'vitest';

vi.mock('./client', () => ({ apiFetch: vi.fn() }));

import { apiFetch } from './client';
import { getPlayer } from './players';

describe('getPlayer', () => {
	test('fetches /api/players/:slug and returns the player', async () => {
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
		vi.mocked(apiFetch).mockResolvedValue({ data: player });

		const result = await getPlayer('mateo-rivera');

		expect(apiFetch).toHaveBeenCalledWith('/api/players/mateo-rivera');
		expect(result).toEqual(player);
	});

	test('URL-encodes the slug so it cannot escape the path segment', async () => {
		vi.mocked(apiFetch).mockResolvedValue({ data: {} });

		await getPlayer('a/../b');

		expect(apiFetch).toHaveBeenCalledWith('/api/players/a%2F..%2Fb');
	});
});
