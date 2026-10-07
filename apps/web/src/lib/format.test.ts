import { describe, expect, test } from 'vitest';
import { formatCategory, formatSurface, formatRound, formatMatchStatus, formatScore, formatHand } from './format';

describe('formatCategory', () => {
	test.each([
		['grand_slam', 'Grand Chelem'],
		['masters_1000', 'Masters 1000'],
		['atp_500', 'ATP 500'],
		['atp_250', 'ATP 250'],
		['wta_1000', 'WTA 1000'],
		['wta_500', 'WTA 500'],
		['wta_250', 'WTA 250']
	])('maps %s to %s', (input, expected) => {
		expect(formatCategory(input)).toBe(expected);
	});

	test('falls back to the raw value for an unmapped category', () => {
		expect(formatCategory('future_category')).toBe('future_category');
	});
});

describe('formatSurface', () => {
	test.each([
		['clay', 'Terre battue'],
		['grass', 'Gazon'],
		['hard', 'Dur'],
		['indoor', 'Indoor']
	])('maps %s to %s', (input, expected) => {
		expect(formatSurface(input)).toBe(expected);
	});

	test('falls back to the raw value for an unmapped surface', () => {
		expect(formatSurface('clay_indoor_hybrid')).toBe('clay_indoor_hybrid');
	});
});

describe('formatRound', () => {
	test.each([
		['r128', '128e de finale'],
		['r64', '64e de finale'],
		['r32', '32e de finale'],
		['r16', '8e de finale'],
		['qf', 'Quart de finale'],
		['sf', 'Demi-finale'],
		['f', 'Finale']
	])('maps %s to %s', (input, expected) => {
		expect(formatRound(input)).toBe(expected);
	});

	test('falls back to the raw value for an unmapped round', () => {
		expect(formatRound('r256')).toBe('r256');
	});
});

describe('formatMatchStatus', () => {
	test.each([
		['scheduled', 'Programmé'],
		['live', 'En direct'],
		['finished', 'Terminé'],
		['retired', 'Abandon'],
		['walkover', 'Forfait'],
		['cancelled', 'Annulé']
	])('maps %s to %s', (input, expected) => {
		expect(formatMatchStatus(input)).toBe(expected);
	});

	test('falls back to the raw value for an unmapped status', () => {
		expect(formatMatchStatus('postponed')).toBe('postponed');
	});
});

describe('formatScore', () => {
	test('formats a straight-sets score', () => {
		const sets = [
			{ set_number: 1, player_a_games: 6, player_b_games: 4, tiebreak_a: null, tiebreak_b: null },
			{ set_number: 2, player_a_games: 6, player_b_games: 3, tiebreak_a: null, tiebreak_b: null }
		];
		expect(formatScore(sets)).toBe('6-4, 6-3');
	});

	test('formats a tiebreak set with the loser tiebreak points', () => {
		const sets = [{ set_number: 1, player_a_games: 7, player_b_games: 6, tiebreak_a: 7, tiebreak_b: 5 }];
		expect(formatScore(sets)).toBe('7-6(5)');
	});

	test('orders sets by set_number regardless of input order', () => {
		const sets = [
			{ set_number: 2, player_a_games: 6, player_b_games: 3, tiebreak_a: null, tiebreak_b: null },
			{ set_number: 1, player_a_games: 6, player_b_games: 4, tiebreak_a: null, tiebreak_b: null }
		];
		expect(formatScore(sets)).toBe('6-4, 6-3');
	});
});

describe('formatHand', () => {
	test.each([
		['left', 'Gaucher'],
		['right', 'Droitier']
	])('maps %s to %s', (input, expected) => {
		expect(formatHand(input)).toBe(expected);
	});

	test('falls back to the raw value for an unmapped hand', () => {
		expect(formatHand('ambidextrous')).toBe('ambidextrous');
	});
});
