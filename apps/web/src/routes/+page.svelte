<script lang="ts">
	import Hero from '#lib/components/Hero.svelte';
	import FeaturedTournaments from '#lib/components/FeaturedTournaments.svelte';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
</script>

<Hero />
<FeaturedTournaments tournaments={data.tournaments} />
