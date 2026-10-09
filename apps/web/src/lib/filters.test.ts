import { describe, expect, test } from 'vitest';
import { parseSurface, parseCategory, parsePage } from './filters';

describe('parseSurface', () => {
	test.each(['clay', 'grass', 'hard', 'indoor'])('accepts %s', (value) => {
		expect(parseSurface(value)).toBe(value);
	});

	test('rejects an unknown surface', () => {
		expect(parseSurface('carpet')).toBeUndefined();
	});

	test('treats null as unset', () => {
		expect(parseSurface(null)).toBeUndefined();
	});
});

describe('parseCategory', () => {
	test.each([
		'grand_slam',
		'masters_1000',
		'atp_500',
		'atp_250',
		'wta_1000',
		'wta_500',
		'wta_250'
	])('accepts %s', (value) => {
		expect(parseCategory(value)).toBe(value);
	});

	test('rejects an unknown category', () => {
		expect(parseCategory('atp_1000')).toBeUndefined();
	});

	test('treats null as unset', () => {
		expect(parseCategory(null)).toBeUndefined();
	});
});

describe('parsePage', () => {
	test('accepts a positive integer', () => {
		expect(parsePage('2')).toBe(2);
	});

	test('treats null as unset', () => {
		expect(parsePage(null)).toBeUndefined();
	});

	test.each(['-1', '0', '2.5', 'abc', '1000000', ''])('rejects %s', (value) => {
		expect(parsePage(value)).toBeUndefined();
	});
});
