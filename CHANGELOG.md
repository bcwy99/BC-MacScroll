# Changelog

## 2.0.0 — BC MacScroll

First release under the new name, forked from UnnaturalScrollWheels 1.4.2.

### Added
- **Middle-click autoscroll**: click the wheel and move the mouse to scroll, or hold and drag. Adjustable speed.
- **Master on/off switch** in the menu bar and Settings.
- **Welcome window** that walks through granting Accessibility access and updates live.
- New app icon and menu bar icon (outlined while paused).
- `--render-docs` mode that renders the README screenshots from the real UI.

### Changed
- Settings window rebuilt in SwiftUI with grouped cards, descriptions and light and dark mode.
- Menu bar menu rebuilt with a status line and quick toggles.
- Launch at login now uses `SMAppService`. The separate AutoLauncher helper app is gone.
- Project moved from an Xcode project and storyboards to Swift Package Manager. It builds with the Command Line Tools alone.
- Requires macOS 13 or later.

### Fixed
- The "Reverse horizontal scrolling" default was saved under a misspelled key.
- Mouse acceleration is now restored only if BC MacScroll was the one that turned it off.
