<script lang="ts">
	import TournamentCard from './TournamentCard.svelte';
	import type { Tournament } from '#lib/api/types';

	let { tournaments }: { tournaments: Tournament[] } = $props();
</script>

<section class="mx-auto max-w-5xl px-4 py-12">
	<h2 class="text-2xl font-semibold text-neutral-900">Tournois en vedette</h2>

	{#if tournaments.length === 0}
		<p class="mt-4 text-neutral-500">Les tournois ne sont pas disponibles pour le moment.</p>
	{:else}
		<div class="mt-6 grid gap-4 sm:grid-cols-3">
			{#each tournaments as tournament (tournament.id)}
				<TournamentCard {tournament} />
			{/each}
		</div>
	{/if}
</section>
