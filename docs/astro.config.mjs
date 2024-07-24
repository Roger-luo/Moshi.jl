import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	site: 'https://moshi.rogerluo.dev',
	base: "/Moshi.jl",
	integrations: [
		starlight({
			title: 'Moshi',
			social: {
				github: 'https://github.com/Roger-luo/Moshi.jl',
			},
			sidebar: [
				{
					label: "Start Here",
					items: [
						{ slug: "start/getting-started" },
						{ slug: "start/algebra-data-type" },
						{ slug: "start/derive" },
						{ slug: "start/match" },
					],
				},
				{
					label: 'Algebraic Data Type',
					items: [
						{ slug: 'data/syntax' },
						{ slug: 'data/pattern' },
						{ slug: 'data/reflection' },
						{ slug: 'data/understand' },
					],
				},
				{
					label: 'Pattern Matching',
					items: [
						{ slug: 'match/syntax' },
						{ slug: 'match/builtin' },
						{ slug: 'match/extend' },
					],
				},
				{
					label: 'Derive Macro',
					items: [
						{ slug: 'derive/syntax' },
						{ slug: 'derive/show' },
						{ slug: 'derive/eq' },
						{ slug: 'derive/hash' },
					],
				},
				{
					label: 'Developer Guide',
					items: [
						{ slug: 'dev/contrib' },
						{ slug: 'dev/doc' },
					],
				},
			],
		}),
	],
});
