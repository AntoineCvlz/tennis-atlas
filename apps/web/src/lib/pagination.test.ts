import { describe, expect, test } from 'vitest';
import { tournamentsHref } from './pagination';

describe('tournamentsHref', () => {
	test('includes the page number', () => {
		expect(tournamentsHref({}, 2)).toBe('/tournaments?page=2');
	});

	test('preserves the surface filter across pages', () => {
		expect(tournamentsHref({ surface: 'clay' }, 3)).toBe('/tournaments?surface=clay&page=3');
	});

	test('preserves both filters across pages', () => {
		expect(tournamentsHref({ surface: 'clay', category: 'grand_slam' }, 1)).toBe(
			'/tournaments?surface=clay&category=grand_slam&page=1'
		);
	});

	test('omits unset filters', () => {
		expect(tournamentsHref({ surface: undefined, category: undefined }, 1)).toBe(
			'/tournaments?page=1'
		);
	});
});
