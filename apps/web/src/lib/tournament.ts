import type { Match, PlayerRef } from './api/types';

export function playersFromMatches(matches: Match[]): PlayerRef[] {
	const byId = new Map<number, PlayerRef>();

	for (const match of matches) {
		if (match.player_a) byId.set(match.player_a.id, match.player_a);
		if (match.player_b) byId.set(match.player_b.id, match.player_b);
	}

	return [...byId.values()].sort((a, b) => a.last_name.localeCompare(b.last_name));
}
