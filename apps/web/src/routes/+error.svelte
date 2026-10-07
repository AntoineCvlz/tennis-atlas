<script lang="ts">
	import { page } from '$app/state';
</script>

<section class="mx-auto max-w-3xl px-4 py-20 text-center">
	<h1 class="text-4xl font-bold text-neutral-900">{page.status}</h1>
	<p class="mt-2 text-neutral-500">{page.error?.message}</p>
	<a href="/tournaments" class="mt-6 inline-block underline">Retour aux tournois</a>
</section>
