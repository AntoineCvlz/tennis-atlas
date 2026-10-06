export type Venue = {
	id: number;
	name: string;
	city: string;
	country_code: string;
};

export type Tournament = {
	id: number;
	name: string;
	slug: string;
	category: string;
	surface: string;
	venue: Venue | null;
};
