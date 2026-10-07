import { API_INTERNAL_URL } from '$app/env/private';

export class ApiError extends Error {
	status: number;

	constructor(message: string, status: number) {
		super(message);
		this.status = status;
	}
}

export async function apiFetch<T>(path: string): Promise<T> {
	const res = await fetch(`${API_INTERNAL_URL}${path}`);

	if (!res.ok) {
		throw new ApiError(`API request failed: ${res.status} ${path}`, res.status);
	}

	return res.json() as Promise<T>;
}
