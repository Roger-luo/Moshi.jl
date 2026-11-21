# Changelog

## [0.4.0](https://github.com/Roger-luo/Moshi.jl/compare/v0.3.13...v0.4.0) (2026-11-21)


### ⚠ BREAKING CHANGES

* **match:** a match with such an || arm now fails to expand instead of throwing when that side matches.

### Features

* **match:** give unreachable-arm warnings a log group ([#103](https://github.com/Roger-luo/Moshi.jl/issues/103)) ([d26717d](https://github.com/Roger-luo/Moshi.jl/commit/d26717d43ae9a3b80dfff3c0a137bcb4c3b79f94))
* **match:** read literal patterns in the unreachable-arm check ([#105](https://github.com/Roger-luo/Moshi.jl/issues/105)) ([b8e3b58](https://github.com/Roger-luo/Moshi.jl/commit/b8e3b58a780f6a508de8588b1c04bb174e1778a1))
* **match:** reject || branches that bind different variables ([#106](https://github.com/Roger-luo/Moshi.jl/issues/106)) ([ffd5cf2](https://github.com/Roger-luo/Moshi.jl/commit/ffd5cf294c2110059ac73af9630be0aaf3f8f54e))
* **match:** warn on unreachable match arms ([#96](https://github.com/Roger-luo/Moshi.jl/issues/96)) ([9be4c21](https://github.com/Roger-luo/Moshi.jl/commit/9be4c21c1c4c7eca87e23e83f26489fc18054af7))


### Bug Fixes

* **data:** accept partially parametrized variant types in isa_variant ([#108](https://github.com/Roger-luo/Moshi.jl/issues/108)) ([9ccab42](https://github.com/Roger-luo/Moshi.jl/commit/9ccab429dccdc609e74ed6c87140d99bc8025de8)), closes [#98](https://github.com/Roger-luo/Moshi.jl/issues/98)
* **data:** convert in setproperty! before storing the value ([#101](https://github.com/Roger-luo/Moshi.jl/issues/101)) ([0611889](https://github.com/Roger-luo/Moshi.jl/commit/0611889821ecea0a76fbeb955462319568936960))
* **data:** reject duplicate variant names in [@data](https://github.com/data) ([#112](https://github.com/Roger-luo/Moshi.jl/issues/112)) ([34702f1](https://github.com/Roger-luo/Moshi.jl/commit/34702f1d8d62fb29239b88940a715daae2b1c1d1))
* **derive:** derived == returns missing for missing fields, like tuples ([#114](https://github.com/Roger-luo/Moshi.jl/issues/114)) ([b0b9451](https://github.com/Roger-luo/Moshi.jl/commit/b0b945136e22fe607cce837d188a3c53d68ca858))
* **derive:** hash ADT variants whose Hash.Cache field is not last ([#113](https://github.com/Roger-luo/Moshi.jl/issues/113)) ([3b7a044](https://github.com/Roger-luo/Moshi.jl/commit/3b7a044cc91b2948b8af3b23307e6f8f3aabaafb))
* **match:** emit arm conditions as jumps so || variables are defined ([#109](https://github.com/Roger-luo/Moshi.jl/issues/109)) ([41e3758](https://github.com/Roger-luo/Moshi.jl/commit/41e375859910f9335d3f1a340d8782fcee6c9b70))
* **match:** quote field names in keyword patterns on plain structs ([#115](https://github.com/Roger-luo/Moshi.jl/issues/115)) ([c7ee289](https://github.com/Roger-luo/Moshi.jl/commit/c7ee289fe669886beb9f225279917652e55293ca))
* **match:** test repeated names in place so every || branch binds them ([#107](https://github.com/Roger-luo/Moshi.jl/issues/107)) ([7a5343c](https://github.com/Roger-luo/Moshi.jl/commit/7a5343ce0618814dd717afc54756c1880adfcde5)), closes [#99](https://github.com/Roger-luo/Moshi.jl/issues/99)
* **match:** treat a missing == result as no match ([#116](https://github.com/Roger-luo/Moshi.jl/issues/116)) ([d5e91bb](https://github.com/Roger-luo/Moshi.jl/commit/d5e91bbc57f205256d3eb39b82b1a68570040025))

## [0.3.13](https://github.com/Roger-luo/Moshi.jl/compare/v0.3.12...v0.3.13) (2026-09-26)


### Bug Fixes

* **data:** bind promoted constructor parameters ([#92](https://github.com/Roger-luo/Moshi.jl/issues/92)) ([8fe64d3](https://github.com/Roger-luo/Moshi.jl/commit/8fe64d3b25056138ea73505dc6d5ce0db94e0f57))
* **match:** emit flat `&&` chains so guards see defined pattern variables ([#93](https://github.com/Roger-luo/Moshi.jl/issues/93)) ([000345a](https://github.com/Roger-luo/Moshi.jl/commit/000345a42b2b17fda3b04cb4f9f1417a3dddd3fe))

## [0.3.12](https://github.com/Roger-luo/Moshi.jl/compare/v0.3.11...v0.3.12) (2026-07-16)


### Features

* **match:** match any AbstractVector via Indexable[...] and abstract-array heads ([#89](https://github.com/Roger-luo/Moshi.jl/issues/89)) ([9cab453](https://github.com/Roger-luo/Moshi.jl/commit/9cab45373356526594ea13daee37a887f03ab005))

## [0.3.11](https://github.com/Roger-luo/Moshi.jl/compare/v0.3.10...v0.3.11) (2026-07-12)


### Features

* **data:** require explicit `()` for singleton variants; deprecate bare form ([#80](https://github.com/Roger-luo/Moshi.jl/issues/80)) ([f79750c](https://github.com/Roger-luo/Moshi.jl/commit/f79750c4b1a7d6af01ae3871a6c43c787b9c33ec))
* **data:** support `export` statement inside `[@data](https://github.com/data)` block ([#86](https://github.com/Roger-luo/Moshi.jl/issues/86)) ([acac360](https://github.com/Roger-luo/Moshi.jl/commit/acac360e6de088432f735a12780349f6eff6c64d)), closes [#45](https://github.com/Roger-luo/Moshi.jl/issues/45)
* **match:** broadcast a constructor pattern over a run ([#26](https://github.com/Roger-luo/Moshi.jl/issues/26)) ([#82](https://github.com/Roger-luo/Moshi.jl/issues/82)) ([a74db69](https://github.com/Roger-luo/Moshi.jl/commit/a74db69f6d80606207d83621ca3ef34bcdf28e19))


### Bug Fixes

* **data:** convert constructor arguments to declared field types ([#83](https://github.com/Roger-luo/Moshi.jl/issues/83)) ([16c3497](https://github.com/Roger-luo/Moshi.jl/commit/16c3497dea185b111b65faba659115d2365653f4)), closes [#32](https://github.com/Roger-luo/Moshi.jl/issues/32)
* **data:** convert self-referential container fields and defaults to declared types ([#85](https://github.com/Roger-luo/Moshi.jl/issues/85)) ([79a1053](https://github.com/Roger-luo/Moshi.jl/commit/79a10532ca1e577387ee5c32de2acaa8400b75a4))

## [0.3.10](https://github.com/Roger-luo/Moshi.jl/compare/v0.3.9...v0.3.10) (2026-07-12)


### Features

* **docs:** redesign site with Astro landing, API docs, and Yan-style logo ([c2afc7d](https://github.com/Roger-luo/Moshi.jl/commit/c2afc7db89d286706f677e852beda2a8f6f6f9f1))
* **match:** support splat interpolation in quoted Expr patterns ([#71](https://github.com/Roger-luo/Moshi.jl/issues/71)) ([5040c32](https://github.com/Roger-luo/Moshi.jl/commit/5040c3282eff084fbbfcbd80f7f77baa7643a677))


### Bug Fixes

* **derive:** support plain structs in [@derive](https://github.com/derive) ([#77](https://github.com/Roger-luo/Moshi.jl/issues/77)) ([b9a841c](https://github.com/Roger-luo/Moshi.jl/commit/b9a841c028df1c7ca28d2bca54b1686a937bc1c4))
* **match:** make isa_variant fallback return false for non-ADT values ([#74](https://github.com/Roger-luo/Moshi.jl/issues/74)) ([b77835e](https://github.com/Roger-luo/Moshi.jl/commit/b77835e93a4372ca93ab1e457cb9f3d524a92ef3)), closes [#43](https://github.com/Roger-luo/Moshi.jl/issues/43)
