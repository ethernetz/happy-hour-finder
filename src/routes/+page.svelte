<script lang="ts">
	import type { PageData } from './$types';

	export let data: PageData;
</script>

<section>
	{#each data.restuarants as restuarant}
		{restuarant.name}
	{/each}
</section>
