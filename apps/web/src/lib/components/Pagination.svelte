<script lang="ts">
	let {
		page,
		totalPages,
		hrefForPage
	}: { page: number; totalPages: number; hrefForPage: (page: number) => string } = $props();
</script>

<nav class="mt-8 flex items-center justify-center gap-4 text-sm">
	{#if page > 1}
		<a href={hrefForPage(page - 1)} class="underline">Précédent</a>
	{:else}
		<span class="text-neutral-400">Précédent</span>
	{/if}

	<span>Page {page} / {Math.max(totalPages, 1)}</span>

	{#if page < totalPages}
		<a href={hrefForPage(page + 1)} class="underline">Suivant</a>
	{:else}
		<span class="text-neutral-400">Suivant</span>
	{/if}
</nav>
