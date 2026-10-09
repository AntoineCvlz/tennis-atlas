import { listTournaments } from '#lib/api/tournaments';
import { parseSurface, parseCategory, parsePage } from '#lib/filters';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ url }) => {
	const surface = parseSurface(url.searchParams.get('surface'));
	const category = parseCategory(url.searchParams.get('category'));
	const page = parsePage(url.searchParams.get('page'));

	const { tournaments, meta } = await listTournaments({ surface, category, page });

	return { tournaments, meta, filters: { surface, category } };
};
