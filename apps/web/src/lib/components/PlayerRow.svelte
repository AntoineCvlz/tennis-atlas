<script lang="ts">
	import type { PlayerRef } from '#lib/api/types';

	let { player }: { player: PlayerRef } = $props();
</script>

<a
	href="/players/{player.slug}"
	class="flex items-center justify-between border-b border-neutral-100 py-2 text-sm hover:text-accent"
>
	<span>{player.first_name} {player.last_name}</span>
</a>
