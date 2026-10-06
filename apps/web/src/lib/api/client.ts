import { API_INTERNAL_URL } from '$app/env/private';

export class ApiError extends Error {}

export async function apiFetch<T>(path: string): Promise<T> {
	const res = await fetch(`${API_INTERNAL_URL}${path}`);

	if (!res.ok) {
		throw new ApiError(`API request failed: ${res.status} ${path}`);
	}

	return res.json() as Promise<T>;
}
