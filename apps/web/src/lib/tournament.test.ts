import { describe, expect, test } from 'vitest';
import { playersFromMatches } from './tournament';
import type { Match } from './api/types';

function buildMatch(overrides: Partial<Match> = {}): Match {
	return {
		id: 1,
		tour: 'atp',
		round: 'qf',
		status: 'finished',
		scheduled_at: null,
		started_at: null,
		finished_at: null,
		best_of: 3,
		winner_id: null,
		player_a: null,
		player_b: null,
		court: null,
		sets: [],
		...overrides
	};
}

describe('playersFromMatches', () => {
	test('deduplicates a player who appears in multiple matches', () => {
		const alice = { id: 1, first_name: 'Alice', last_name: 'Martin', slug: 'alice-martin' };
		const bob = { id: 2, first_name: 'Bob', last_name: 'Nguyen', slug: 'bob-nguyen' };
		const matches = [
			buildMatch({ id: 1, player_a: alice, player_b: bob }),
			buildMatch({ id: 2, player_a: alice, player_b: null })
		];

		const result = playersFromMatches(matches);

		expect(result).toHaveLength(2);
		expect(result.map((p) => p.id).sort()).toEqual([1, 2]);
	});

	test('sorts by last name', () => {
		const nguyen = { id: 1, first_name: 'Bob', last_name: 'Nguyen', slug: 'bob-nguyen' };
		const martin = { id: 2, first_name: 'Alice', last_name: 'Martin', slug: 'alice-martin' };
		const matches = [buildMatch({ player_a: nguyen, player_b: martin })];

		const result = playersFromMatches(matches);

		expect(result.map((p) => p.last_name)).toEqual(['Martin', 'Nguyen']);
	});

	test('ignores null players (byes)', () => {
		const matches = [buildMatch({ player_a: null, player_b: null })];

		expect(playersFromMatches(matches)).toEqual([]);
	});
});
