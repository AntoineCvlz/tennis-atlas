import { beforeEach, describe, expect, test, vi } from 'vitest';

vi.mock('$app/env/private', () => ({ API_INTERNAL_URL: 'http://api:4000' }));

import { apiFetch, ApiError } from './client';

describe('apiFetch', () => {
	beforeEach(() => {
		vi.restoreAllMocks();
	});

	test('returns parsed JSON on a 200 response, fetched from API_INTERNAL_URL', async () => {
		vi.stubGlobal(
			'fetch',
			vi.fn().mockResolvedValue({
				ok: true,
				status: 200,
				json: () => Promise.resolve({ data: ['ok'] })
			})
		);

		const result = await apiFetch<{ data: string[] }>('/api/tournaments');

		expect(result).toEqual({ data: ['ok'] });
		expect(fetch).toHaveBeenCalledWith('http://api:4000/api/tournaments');
	});

	test('throws ApiError on a non-ok response', async () => {
		vi.stubGlobal(
			'fetch',
			vi.fn().mockResolvedValue({ ok: false, status: 500, json: () => Promise.resolve({}) })
		);

		await expect(apiFetch('/api/tournaments')).rejects.toThrow(ApiError);
	});

	test('propagates a network error unchanged', async () => {
		vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('network down')));

		await expect(apiFetch('/api/tournaments')).rejects.toThrow('network down');
	});
});
