import { defineEnvVars } from '@sveltejs/kit/env';

export const variables = defineEnvVars({
	PUBLIC_API_URL: {
		public: true,
		static: false
	},
	API_INTERNAL_URL: {
		public: false,
		static: false
	}
});
