<script lang="ts">
	import { formatRound } from '#lib/format';
	import MatchRow from './MatchRow.svelte';
	import type { Match } from '#lib/api/types';

	let { matches, emptyMessage }: { matches: Match[]; emptyMessage: string } = $props();

	const ROUND_ORDER = ['r128', 'r64', 'r32', 'r16', 'qf', 'sf', 'f'];

	function groupByRound(items: Match[]): Array<{ round: string; matches: Match[] }> {
		const groups = new Map<string, Match[]>();
		for (const match of items) {
			const list = groups.get(match.round) ?? [];
			list.push(match);
			groups.set(match.round, list);
		}
		return ROUND_ORDER.filter((round) => groups.has(round)).map((round) => ({
			round,
			matches: groups.get(round) ?? []
		}));
	}

	let groups = $derived(groupByRound(matches));
</script>

{#if matches.length === 0}
	<p class="mt-4 text-neutral-500">{emptyMessage}</p>
{:else}
	<div class="mt-4 space-y-6">
		{#each groups as group (group.round)}
			<div>
				<h3 class="mb-2 text-sm font-semibold uppercase text-neutral-500">
					{formatRound(group.round)}
				</h3>
				{#each group.matches as match (match.id)}
					<MatchRow {match} />
				{/each}
			</div>
		{/each}
	</div>
{/if}
