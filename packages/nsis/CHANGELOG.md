# nsis

## 4.0.3

### Patch Changes

- [`7f17630`](https://github.com/mmaietta/electron-builder-binaries/commit/7f176300f9be342efe52831aa017f3dbf0d7f431) Thanks [@mmaietta](https://github.com/mmaietta)! - chore: trigger release

## 4.0.2

### Patch Changes

- [`57c9d48`](https://github.com/mmaietta/electron-builder-binaries/commit/57c9d484ea2ac7360a07368c50d707e411f944c9) Thanks [@mmaietta](https://github.com/mmaietta)! - chore: change compression method

## 4.0.1

### Patch Changes

- [`73f7a22`](https://github.com/mmaietta/electron-builder-binaries/commit/73f7a22120fec06a40dfc074b8f70608d7d4dfcf) Thanks [@mmaietta](https://github.com/mmaietta)! - recompress binary with flags `7za a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=64m -ms=on` to avoid corruption of internal files during archive

## 4.0.0

### Major Changes

- [`580105e`](https://github.com/mmaietta/electron-builder-binaries/commit/580105eb0cd6fdcc5b4b4bdae1f8afada0486cb9) Thanks [@mmaietta](https://github.com/mmaietta)! - test

## 1.0.0

### Major Changes

- [#46](https://github.com/mmaietta/electron-builder-binaries/pull/46) [`feab41e`](https://github.com/mmaietta/electron-builder-binaries/commit/feab41ec1a226a86afaa304a2f2c68dfd2799d35) Thanks [@mmaietta](https://github.com/mmaietta)! - chore(nsis): create deployment pipeline for makensis on windows/mac/linux
