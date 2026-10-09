<script lang="ts">
	import Pagination from '#lib/components/Pagination.svelte';
	import FilterForm from '#lib/components/FilterForm.svelte';
	import TournamentCard from '#lib/components/TournamentCard.svelte';
	import { tournamentsHref } from '#lib/pagination';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	function hrefForPage(page: number): string {
		return tournamentsHref(data.filters, page);
	}
</script>

<section class="mx-auto max-w-5xl px-4 py-12">
	<h1 class="text-2xl font-semibold text-neutral-900">Tournois</h1>

	<FilterForm filters={data.filters} />

	{#if data.tournaments.length === 0}
		<p class="mt-6 text-neutral-500">Aucun tournoi ne correspond à ces filtres.</p>
	{:else}
		<div class="mt-6 grid gap-4 sm:grid-cols-3">
			{#each data.tournaments as tournament (tournament.id)}
				<TournamentCard {tournament} />
			{/each}
		</div>
		<Pagination page={data.meta.page} totalPages={data.meta.total_pages} {hrefForPage} />
	{/if}
</section>
