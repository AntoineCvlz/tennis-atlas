import { apiFetch } from './client';
import type { Player } from './types';

export async function getPlayer(slug: string): Promise<Player> {
	const { data } = await apiFetch<{ data: Player }>(`/api/players/${slug}`);
	return data;
}
