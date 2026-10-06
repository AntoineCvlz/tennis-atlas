<script lang="ts">
	import { formatCategory, formatSurface } from '#lib/format';
	import type { Tournament } from '#lib/api/types';

	let { tournament }: { tournament: Tournament } = $props();
</script>

<article class="rounded-lg border border-neutral-200 p-5">
	<h3 class="font-semibold text-neutral-900">{tournament.name}</h3>
	<p class="mt-1 text-sm text-neutral-500">
		{formatCategory(tournament.category)} · {formatSurface(tournament.surface)}
	</p>
</article>
