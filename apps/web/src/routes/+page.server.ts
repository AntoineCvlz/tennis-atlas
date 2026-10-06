import { getTournaments } from '#lib/api/tournaments';
import type { PageServerLoad } from './$types';

const FEATURED_COUNT = 3;

export const load: PageServerLoad = async () => {
	try {
		const tournaments = await getTournaments();
		return { tournaments: tournaments.slice(0, FEATURED_COUNT), apiError: false };
	} catch {
		return { tournaments: [], apiError: true };
	}
};
