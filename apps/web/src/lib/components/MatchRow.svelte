<script lang="ts">
	import { formatMatchStatus, formatScore } from '#lib/format';
	import type { Match, PlayerRef } from '#lib/api/types';

	let { match }: { match: Match } = $props();

	function playerLabel(player: PlayerRef | null): string {
		return player ? `${player.first_name} ${player.last_name}` : 'BYE';
	}
</script>

<div class="flex items-center justify-between border-b border-neutral-100 py-2 text-sm">
	<div class="flex gap-2">
		<span
			class={match.winner_id === match.player_a?.id
				? 'font-semibold text-neutral-900'
				: 'text-neutral-700'}
		>
			{playerLabel(match.player_a)}
		</span>
		<span class="text-neutral-400">vs</span>
		<span
			class={match.winner_id === match.player_b?.id
				? 'font-semibold text-neutral-900'
				: 'text-neutral-700'}
		>
			{playerLabel(match.player_b)}
		</span>
	</div>
	<div class="flex gap-3 text-neutral-500">
		{#if match.sets.length > 0}
			<span>{formatScore(match.sets)}</span>
		{/if}
		<span>{formatMatchStatus(match.status)}</span>
	</div>
</div>
