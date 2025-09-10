---
"nsis": patch
---

recompress binary with flags `7za a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=64m -ms=on` to avoid corruption of internal files during archive
