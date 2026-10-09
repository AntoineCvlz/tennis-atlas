import { error } from '@sveltejs/kit';
import { ApiError } from '#lib/api/client';
import { getPlayer } from '#lib/api/players';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params }) => {
	try {
		const player = await getPlayer(params.slug);
		return { player };
	} catch (e) {
		if (e instanceof ApiError && e.status === 404) {
			throw error(404, 'Joueur introuvable');
		}
		throw e;
	}
};
