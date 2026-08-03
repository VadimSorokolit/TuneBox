# Vendor

## SFBAudioEngine

Local checkout of [martonfarago/SFBAudioEngine](https://github.com/martonfarago/SFBAudioEngine) with a TuneBox patch:

- `SFBDSDPCMDecoder` accepts DSD64 / DSD128 / DSD256 (and 48 kHz variants) for DSD→PCM playback on iOS.

Xcode resolves this package via `../Vendor/SFBAudioEngine` (not the remote SPM URL).
