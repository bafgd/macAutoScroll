# AutoScroll for macOS

Windows has had middle-click autoscroll but macOS never has this useful feature.  **AutoScroll** brings that same behavior to Macs.

## Features

- Built on the same features in Windows
- Variable scroll speed based on how far you move from the click point
- Lightweight, lives in the menu bar
- Customizability through the menu bar

## Not Notarized by Apple

This app isn't signed with an Apple Developer certificate, so **Gatekeeper will block it the first time you open it**, with a message like:

> "AutoScroll" can't be opened because Apple cannot check it for malicious software.

This is expected, not a bug. Here's how to get past it:

1. Try to open the app — you'll see the warning above. Click **Done** (not "Move to Trash").
2. Open **System Settings → Privacy & Security**.
3. Scroll down to the **Security** section — you'll see a note that AutoScroll was blocked.
4. Click **Open Anyway**.
5. Confirm in the follow-up dialog (this may ask for Touch ID or your password).

You only need to do this once per install/update.

## Installation

### Homebrew (recommended)

```bash
brew install --cask bafgd/autoscroll/autoscroll
```

### Manual download

1. Download the latest `.dmg` from the [Releases page](#).
2. Open it and drag **AutoScroll** into **Applications**.
3. Launch it and follow the [Gatekeeper steps]([#-not-notarized-by-apple](https://github.com/bafgd/macAutoScroll#not-notarized-by-apple)) above.

## Permissions

AutoScroll needs **Accessibility** access to simulate scroll input:

`System Settings → Privacy & Security → Accessibility` → enable **AutoScroll**.

## Usage

- Drag in any direction while holding the middle mouse button
- Release the middle mouse button to stop scrolling
- Customize settings through the menu bar icon

## License

[GPL-3.0 license](LICENSE)

## Contributing

Issues and PRs welcome. If something breaks after a macOS update, please open an issue with your macOS version.
