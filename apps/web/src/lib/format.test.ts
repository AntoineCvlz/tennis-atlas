import { describe, expect, test } from 'vitest';
import { formatCategory, formatSurface } from './format';

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
