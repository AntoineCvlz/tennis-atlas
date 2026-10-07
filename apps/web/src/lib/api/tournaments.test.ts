import { describe, expect, test, vi } from 'vitest';

vi.mock('./client', () => ({ apiFetch: vi.fn() }));

import { apiFetch } from './client';
import { getTournaments, listTournaments, getTournament, getMatchesForEdition } from './tournaments';

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

describe('listTournaments', () => {
	test('builds the query string from the given filters and page', async () => {
		const tournaments = [
			{ id: 1, name: 'A', slug: 'a', category: 'atp_250', surface: 'hard', venue: null }
		];
		const meta = { page: 2, page_size: 20, total_count: 1, total_pages: 1 };
		vi.mocked(apiFetch).mockResolvedValue({ data: tournaments, meta });

		const result = await listTournaments({ surface: 'clay', category: 'grand_slam', page: 2 });

		expect(apiFetch).toHaveBeenCalledWith(
			'/api/tournaments?surface=clay&category=grand_slam&page=2'
		);
		expect(result).toEqual({ tournaments, meta });
	});

	test('omits unset filters from the query string', async () => {
		const meta = { page: 1, page_size: 20, total_count: 0, total_pages: 0 };
		vi.mocked(apiFetch).mockResolvedValue({ data: [], meta });

		await listTournaments({});

		expect(apiFetch).toHaveBeenCalledWith('/api/tournaments?');
	});
});

describe('getTournament', () => {
	test('fetches /api/tournaments/:slug and returns the detail payload', async () => {
		const tournament = {
			id: 1,
			name: 'A',
			slug: 'a',
			category: 'grand_slam',
			surface: 'clay',
			venue: null,
			description: null,
			logo_url: null,
			hero_image_url: null,
			editions: []
		};
		vi.mocked(apiFetch).mockResolvedValue({ data: tournament });

		const result = await getTournament('a');

		expect(apiFetch).toHaveBeenCalledWith('/api/tournaments/a');
		expect(result).toEqual(tournament);
	});
});

describe('getMatchesForEdition', () => {
	test('fetches the edition matches with a large page_size', async () => {
		vi.mocked(apiFetch).mockResolvedValue({ data: [] });

		const result = await getMatchesForEdition('a', 2025);

		expect(apiFetch).toHaveBeenCalledWith('/api/tournaments/a/editions/2025/matches?page_size=100');
		expect(result).toEqual([]);
	});
});
