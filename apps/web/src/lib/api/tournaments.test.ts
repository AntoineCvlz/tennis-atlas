import { describe, expect, test, vi } from 'vitest';

vi.mock('./client', () => ({ apiFetch: vi.fn() }));

import { apiFetch } from './client';
import { getTournaments } from './tournaments';

describe('getTournaments', () => {
	test('fetches /api/tournaments and returns the data array', async () => {
		const tournaments = [
			{
				id: 1,
				name: 'Internationaux Fictifs de France',
				slug: 'internationaux-fictifs-de-france',
				category: 'grand_slam',
				surface: 'clay',
				venue: null
			}
		];
		vi.mocked(apiFetch).mockResolvedValue({ data: tournaments });

		const result = await getTournaments();

		expect(apiFetch).toHaveBeenCalledWith('/api/tournaments');
		expect(result).toEqual(tournaments);
	});
});
