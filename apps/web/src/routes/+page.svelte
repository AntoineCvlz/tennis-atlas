<script lang="ts">
  import { onMount } from 'svelte';
  import { env } from '$env/dynamic/public';

  type HealthStatus = { status: string; database: string };

  const RETRY_INTERVAL_MS = 2000;
  const MAX_RETRY_MS = 90_000;

  let health = $state<HealthStatus | null>(null);
  let error = $state<string | null>(null);

  onMount(() => {
    let cancelled = false;
    const startedAt = Date.now();

    async function attempt() {
      try {
        const res = await fetch(`${env.PUBLIC_API_URL}/api/health`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        if (cancelled) return;
        health = data;
      } catch (e) {
        if (cancelled) return;
        if (Date.now() - startedAt >= MAX_RETRY_MS) {
          error = e instanceof Error ? e.message : 'Unknown error';
          return;
        }
        setTimeout(attempt, RETRY_INTERVAL_MS);
      }
    }

    attempt();

    return () => {
      cancelled = true;
    };
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
