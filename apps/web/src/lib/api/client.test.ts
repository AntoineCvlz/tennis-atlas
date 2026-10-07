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

	test('throws ApiError carrying the response status on a non-ok response', async () => {
		vi.stubGlobal(
			'fetch',
			vi.fn().mockResolvedValue({ ok: false, status: 404, json: () => Promise.resolve({}) })
		);

		const thrown: unknown = await apiFetch('/api/tournaments/unknown').catch((e) => e);

		expect(thrown).toBeInstanceOf(ApiError);
		expect((thrown as ApiError).status).toBe(404);
	});

	test('propagates a network error unchanged', async () => {
		vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('network down')));

		await expect(apiFetch('/api/tournaments')).rejects.toThrow('network down');
	});
});
