import { describe, expect, test, vi } from 'vitest';

vi.mock('#lib/api/tournaments', () => ({ listTournaments: vi.fn() }));

import { listTournaments } from '#lib/api/tournaments';
import { load } from './+page.server';

function buildEvent(search: string) {
	return { url: new URL(`http://localhost/tournaments${search}`) } as unknown as Parameters<
		typeof load
	>[0];
}

describe('load', () => {
	test('passes filters and page parsed from the URL to listTournaments', async () => {
		const meta = { page: 2, page_size: 20, total_count: 5, total_pages: 1 };
		vi.mocked(listTournaments).mockResolvedValue({ tournaments: [], meta });

		await load(buildEvent('?surface=clay&category=grand_slam&page=2'));

		expect(listTournaments).toHaveBeenCalledWith({
			surface: 'clay',
			category: 'grand_slam',
			page: 2
		});
	});

	test('passes undefined filters and page when the URL has none', async () => {
		const meta = { page: 1, page_size: 20, total_count: 0, total_pages: 0 };
		vi.mocked(listTournaments).mockResolvedValue({ tournaments: [], meta });

		await load(buildEvent(''));

		expect(listTournaments).toHaveBeenCalledWith({
			surface: undefined,
			category: undefined,
			page: undefined
		});
	});

	test('returns tournaments, meta, and the active filters', async () => {
		const meta = { page: 1, page_size: 20, total_count: 1, total_pages: 1 };
		const tournaments = [
			{ id: 1, name: 'A', slug: 'a', category: 'atp_250', surface: 'hard', venue: null }
		];
		vi.mocked(listTournaments).mockResolvedValue({ tournaments, meta });

		const result = await load(buildEvent('?surface=hard'));

		expect(result).toEqual({
			tournaments,
			meta,
			filters: { surface: 'hard', category: undefined }
		});
	});
});
