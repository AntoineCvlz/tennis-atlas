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

// Named `MatchSet`, not `Set` — `Set` would shadow the built-in JS/TS type.
export type MatchSet = {
	set_number: number;
	player_a_games: number;
	player_b_games: number;
	tiebreak_a: number | null;
	tiebreak_b: number | null;
};

export type PlayerRef = {
	id: number;
	first_name: string;
	last_name: string;
	slug: string;
};

export type CourtRef = {
	id: number;
	name: string;
	surface: string;
};

export type Match = {
	id: number;
	tour: string;
	round: string;
	status: string;
	scheduled_at: string | null;
	started_at: string | null;
	finished_at: string | null;
	best_of: number;
	winner_id: number | null;
	player_a: PlayerRef | null;
	player_b: PlayerRef | null;
	court: CourtRef | null;
	sets: MatchSet[];
};

export type TournamentEdition = {
	id: number;
	year: number;
	start_date: string;
	end_date: string;
	status: string;
};

export type TournamentDetail = Tournament & {
	description: string | null;
	logo_url: string | null;
	hero_image_url: string | null;
	editions: TournamentEdition[];
};

export type Player = {
	id: number;
	first_name: string;
	last_name: string;
	slug: string;
	country_code: string;
	current_ranking: number | null;
	current_ranking_points: number | null;
	birth_date: string | null;
	hand: string | null;
	height_cm: number | null;
};

export type PageMeta = {
	page: number;
	page_size: number;
	total_count: number;
	total_pages: number;
};
