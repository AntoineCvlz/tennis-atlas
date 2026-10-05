<script lang="ts">
  import { onMount } from 'svelte';
  import { env } from '$env/dynamic/public';

  type HealthStatus = { status: string; database: string };

  let health = $state<HealthStatus | null>(null);
  let error = $state<string | null>(null);

  onMount(async () => {
    try {
      const res = await fetch(`${env.PUBLIC_API_URL}/api/health`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      health = await res.json();
    } catch (e) {
      error = e instanceof Error ? e.message : 'Unknown error';
    }
  });
</script>

<main>
  <h1>Tennis Atlas</h1>
  <p>Explore the world of tennis.</p>

  {#if error}
    <p>API unreachable: {error}</p>
  {:else if health}
    <p>API status: {health.status} — database: {health.database}</p>
  {:else}
    <p>Checking API connection…</p>
  {/if}
</main>
