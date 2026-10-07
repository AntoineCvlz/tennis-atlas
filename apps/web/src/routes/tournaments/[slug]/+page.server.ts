import { error } from '@sveltejs/kit';
import { ApiError } from '#lib/api/client';
import { getTournament, getMatchesForEdition } from '#lib/api/tournaments';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params }) => {
	let tournament;
	try {
		tournament = await getTournament(params.slug);
	} catch (e) {
		if (e instanceof ApiError && e.status === 404) {
			throw error(404, 'Tournoi introuvable');
		}
		throw e;
	}

	const edition = tournament.editions[0] ?? null;
	const matches = edition ? await getMatchesForEdition(params.slug, edition.year) : [];

	return { tournament, edition, matches };
};
