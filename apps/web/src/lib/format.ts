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
