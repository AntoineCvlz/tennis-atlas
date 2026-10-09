const VALID_SURFACES = new Set(['clay', 'grass', 'hard', 'indoor']);

const VALID_CATEGORIES = new Set([
	'grand_slam',
	'masters_1000',
	'atp_500',
	'atp_250',
	'wta_1000',
	'wta_500',
	'wta_250'
]);

export function parseSurface(value: string | null): string | undefined {
	return value !== null && VALID_SURFACES.has(value) ? value : undefined;
}

export function parseCategory(value: string | null): string | undefined {
	return value !== null && VALID_CATEGORIES.has(value) ? value : undefined;
}

export function parsePage(value: string | null): number | undefined {
	if (value === null || value === '') return undefined;
	const page = Number(value);
	return Number.isInteger(page) && page > 0 && page < 1_000_000 ? page : undefined;
}
