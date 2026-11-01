# Nashi for Windows

Nashi's Windows development build uses WPF and .NET 10. The current branch adds a compact monochrome pill workspace with file selection, searchable tools, web downloads, Windows media controls, history and customizable visibility. See the [project overview](../README.md) or [Türkçe tanıtım](../README.tr.md) for screenshots and limitations.

## Build

Install the .NET 10 SDK on Windows x64, then run from the repository root:

```powershell
dotnet publish windows/Nashi.Windows -c Release -o build/windows/Nashi
.\build\windows\Nashi\Nashi.exe
```

The published folder is self-contained. Keep its files together. Some media, office and metadata features require additional tools; their versions, hashes and licenses are documented in [dependencies](../docs/dependencies.md). An unsigned [Windows preview ZIP](https://github.com/Alp-a-max/nashi-app/releases/tag/v1.0-preview) is available. Existing update code checks upstream Nashi; installing an offered update can replace this preview with the upstream app. Disable automatic checks in Settings → Updates and do not install an upstream update to keep this version.

## Use

Enable pill mode in Settings. The default show/hide shortcut is **Ctrl+Alt+N**, configurable in Settings. Visibility options include shortcut, fixed, smart and peek. Position, monitor, hover and collapse delays are configurable. Smart mode uses the foreground window; Peek responds to media changes and Nashi notifications. Full-screen games, anti-cheat software and physical multi-monitor configurations need further testing.

**Ctrl+O** opens the file picker. **Ctrl+V** imports files, text, images or links when a text field is not being edited. **Ctrl+Shift+D** opens a copied public media link. In the Home file list, Delete removes selected entries from Nashi without deleting the original files. Explorer drag modifiers and other shortcuts are configurable in Settings.

Preferences and the library live in `%LOCALAPPDATA%\Nashi`. The media visualizer uses the default Windows output level and is active only when needed; it is not a per-application audio capture.

## Verify

```powershell
dotnet build windows/Nashi.Windows -c Release
dotnet run --project windows/Nashi.Verify -c Release
```

See the [isolated UI audit](../docs/testing/UI-AUDIT.md) and [feature parity notes](FEATURE-PARITY.md). Automated renders and synthetic checks do not replace real pointer, game or multi-monitor testing. Dependencies retain their own licenses; see [third-party notices](THIRD-PARTY-NOTICES.txt).
