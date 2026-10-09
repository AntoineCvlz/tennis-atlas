<script lang="ts">
	import { formatCategory, formatSurface } from '#lib/format';
	import MatchList from '#lib/components/MatchList.svelte';
	import PlayerRow from '#lib/components/PlayerRow.svelte';
	import { playersFromMatches } from '#lib/tournament';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	type Tab = 'schedule' | 'players' | 'results';
	let activeTab = $state<Tab>('results');

	let players = $derived(playersFromMatches(data.matches));
	let scheduledMatches = $derived(
		data.matches.filter((m) => m.status === 'scheduled' || m.status === 'live')
	);
	let finishedMatches = $derived(
		data.matches.filter((m) => m.status !== 'scheduled' && m.status !== 'live')
	);

	function tabClass(tab: Tab): string {
		return activeTab === tab
			? 'border-b-2 border-accent pb-2 font-semibold text-neutral-900'
			: 'pb-2 text-neutral-500';
	}
</script>

<section class="mx-auto max-w-5xl px-4 py-12">
	<h1 class="text-3xl font-bold text-neutral-900">{data.tournament.name}</h1>
	<p class="mt-1 text-neutral-500">
		{formatCategory(data.tournament.category)} · {formatSurface(data.tournament.surface)}
		{#if data.edition}
			· {data.edition.year}
		{/if}
	</p>

	<div class="mt-6 flex gap-4 border-b border-neutral-200 text-sm">
		<button class={tabClass('schedule')} onclick={() => (activeTab = 'schedule')}>
			Calendrier
		</button>
		<button class={tabClass('players')} onclick={() => (activeTab = 'players')}> Joueurs </button>
		<button class={tabClass('results')} onclick={() => (activeTab = 'results')}> Résultats </button>
	</div>

	{#if activeTab === 'schedule'}
		<MatchList matches={scheduledMatches} emptyMessage="Aucun match à venir programmé." />
	{:else if activeTab === 'players'}
		{#if players.length === 0}
			<p class="mt-4 text-neutral-500">Aucun joueur à afficher.</p>
		{:else}
			<div class="mt-4">
				{#each players as player (player.id)}
					<PlayerRow {player} />
				{/each}
			</div>
		{/if}
	{:else if activeTab === 'results'}
		<MatchList matches={finishedMatches} emptyMessage="Aucun résultat pour l'instant." />
	{/if}
</section>
