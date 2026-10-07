import { listTournaments } from '#lib/api/tournaments';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ url }) => {
	const surface = url.searchParams.get('surface') ?? undefined;
	const category = url.searchParams.get('category') ?? undefined;
	const pageParam = url.searchParams.get('page');
	const page = pageParam ? Number(pageParam) : undefined;

	const { tournaments, meta } = await listTournaments({ surface, category, page });

	return { tournaments, meta, filters: { surface, category } };
};
