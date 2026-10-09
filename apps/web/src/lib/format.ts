const CATEGORY_LABELS: Record<string, string> = {
	grand_slam: 'Grand Chelem',
	masters_1000: 'Masters 1000',
	atp_500: 'ATP 500',
	atp_250: 'ATP 250',
	wta_1000: 'WTA 1000',
	wta_500: 'WTA 500',
	wta_250: 'WTA 250'
};

const SURFACE_LABELS: Record<string, string> = {
	clay: 'Terre battue',
	grass: 'Gazon',
	hard: 'Dur',
	indoor: 'Indoor'
};

export function formatCategory(category: string): string {
	return CATEGORY_LABELS[category] ?? category;
}

export function formatSurface(surface: string): string {
	return SURFACE_LABELS[surface] ?? surface;
}

import type { MatchSet } from './api/types';

const ROUND_LABELS: Record<string, string> = {
	r128: '128e de finale',
	r64: '64e de finale',
	r32: '32e de finale',
	r16: '8e de finale',
	qf: 'Quart de finale',
	sf: 'Demi-finale',
	f: 'Finale'
};

const MATCH_STATUS_LABELS: Record<string, string> = {
	scheduled: 'Programmé',
	live: 'En direct',
	finished: 'Terminé',
	retired: 'Abandon',
	walkover: 'Forfait',
	cancelled: 'Annulé'
};

const HAND_LABELS: Record<string, string> = {
	left: 'Gaucher',
	right: 'Droitier'
};

export function formatRound(round: string): string {
	return ROUND_LABELS[round] ?? round;
}

export function formatMatchStatus(status: string): string {
	return MATCH_STATUS_LABELS[status] ?? status;
}

export function formatHand(hand: string): string {
	return HAND_LABELS[hand] ?? hand;
}

export function formatScore(sets: MatchSet[]): string {
	return [...sets]
		.sort((a, b) => a.set_number - b.set_number)
		.map((s) => {
			const base = `${s.player_a_games}-${s.player_b_games}`;
			return s.tiebreak_a !== null && s.tiebreak_b !== null
				? `${base}(${Math.min(s.tiebreak_a, s.tiebreak_b)})`
				: base;
		})
		.join(', ');
}
