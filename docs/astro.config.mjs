import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

const site =
	process.env.SITE_URL ??
	(process.env.VERCEL_URL
		? `https://${process.env.VERCEL_URL}`
		: 'https://moshi.rogerluo.dev');
const base = process.env.BASE_PATH ?? '/';

// https://astro.build/config
export default defineConfig({
	site,
	base,
	integrations: [
		starlight({
			title: 'Moshi.jl',
			description:
				'Algebraic data types, pattern matching, and trait derivation for Julia.',
			logo: {
				src: './src/assets/logo.svg',
				alt: 'Moshi.jl',
				replacesTitle: false,
			},
			customCss: ['./src/styles/custom.css'],
			social: [
				{
					icon: 'github',
					label: 'GitHub',
					href: 'https://github.com/Roger-luo/Moshi.jl',
				},
			],
			head: [
				{
					tag: 'link',
					attrs: {
						rel: 'preconnect',
						href: 'https://fonts.googleapis.com',
					},
				},
				{
					tag: 'link',
					attrs: {
						rel: 'preconnect',
						href: 'https://fonts.gstatic.com',
						crossorigin: true,
					},
				},
				{
					tag: 'link',
					attrs: {
						rel: 'stylesheet',
						href: 'https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,400;0,9..40,500;0,9..40,600;0,9..40,700;1,9..40,400&family=JetBrains+Mono:wght@400;500;600&display=swap',
					},
				},
			],
			sidebar: [
				{
					label: 'Start Here',
					items: [
						{ slug: 'start/getting-started' },
						{ slug: 'start/algebra-data-type' },
						{ slug: 'start/match' },
						{ slug: 'start/derive' },
					],
				},
				{
					label: 'API Reference',
					items: [
						{ slug: 'api/data' },
						{ slug: 'api/match' },
						{ slug: 'api/derive' },
					],
				},
				{
					label: 'Algebraic Data Type',
					items: [
						{ slug: 'data/syntax' },
						{ slug: 'data/reflection' },
						{ slug: 'data/understand' },
						{ slug: 'data/benchmark' },
					],
				},
				{
					label: 'Pattern Matching',
					items: [
						{ slug: 'match/syntax' },
						{ slug: 'match/extend' },
						{ slug: 'match/behind' },
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
