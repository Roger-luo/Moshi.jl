# Changelog

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
