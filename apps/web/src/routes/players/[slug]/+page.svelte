<script lang="ts">
	import { formatHand } from '#lib/format';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
</script>

<section class="mx-auto max-w-3xl px-4 py-12">
	<h1 class="text-3xl font-bold text-neutral-900">
		{data.player.first_name} {data.player.last_name}
	</h1>
	<p class="mt-1 text-neutral-500">{data.player.country_code}</p>

	<dl class="mt-6 grid grid-cols-2 gap-4 text-sm">
		{#if data.player.current_ranking}
			<div>
				<dt class="text-neutral-500">Classement</dt>
				<dd class="font-semibold text-neutral-900">#{data.player.current_ranking}</dd>
			</div>
		{/if}
		{#if data.player.hand}
			<div>
				<dt class="text-neutral-500">Main</dt>
				<dd class="font-semibold text-neutral-900">{formatHand(data.player.hand)}</dd>
			</div>
		{/if}
		{#if data.player.height_cm}
			<div>
				<dt class="text-neutral-500">Taille</dt>
				<dd class="font-semibold text-neutral-900">{data.player.height_cm} cm</dd>
			</div>
		{/if}
		{#if data.player.birth_date}
			<div>
				<dt class="text-neutral-500">Date de naissance</dt>
				<dd class="font-semibold text-neutral-900">{data.player.birth_date}</dd>
			</div>
		{/if}
	</dl>
</section>
