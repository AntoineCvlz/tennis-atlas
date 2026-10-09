<script lang="ts">
	let { filters }: { filters: { surface?: string; category?: string } } = $props();
</script>

<form method="GET" class="mt-6 flex flex-wrap items-end gap-4">
	<label class="flex flex-col text-sm text-neutral-600">
		Surface
		<select
			name="surface"
			value={filters.surface ?? ''}
			class="mt-1 rounded border border-neutral-300 px-2 py-1"
		>
			<option value="">Toutes</option>
			<option value="clay">Terre battue</option>
			<option value="grass">Gazon</option>
			<option value="hard">Dur</option>
			<option value="indoor">Indoor</option>
		</select>
	</label>

	<label class="flex flex-col text-sm text-neutral-600">
		Catégorie
		<select
			name="category"
			value={filters.category ?? ''}
			class="mt-1 rounded border border-neutral-300 px-2 py-1"
		>
			<option value="">Toutes</option>
			<option value="grand_slam">Grand Chelem</option>
			<option value="masters_1000">Masters 1000</option>
			<option value="atp_500">ATP 500</option>
			<option value="atp_250">ATP 250</option>
			<option value="wta_1000">WTA 1000</option>
			<option value="wta_500">WTA 500</option>
			<option value="wta_250">WTA 250</option>
		</select>
	</label>

	<button type="submit" class="rounded bg-accent px-4 py-1 text-white">Filtrer</button>
</form>
