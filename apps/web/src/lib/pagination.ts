export function tournamentsHref(
	filters: { surface?: string; category?: string },
	page: number
): string {
	const params = new URLSearchParams();
	if (filters.surface) params.set('surface', filters.surface);
	if (filters.category) params.set('category', filters.category);
	params.set('page', String(page));
	return `/tournaments?${params.toString()}`;
}
