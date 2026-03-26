# Claude Code Notification Hook

A native macOS notification popup for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that shows conversation context when Claude needs your attention.

![macOS only](https://img.shields.io/badge/platform-macOS-lightgrey)



https://github.com/user-attachments/assets/914b5c93-9026-4537-8b14-14ad1e8b8d0d





## Features

- **Native floating panel** — SwiftUI HUD-style notification (no ugly AppleScript dialogs)
- **Conversation context** — Shows the last user/assistant exchange so you know what's going on
- **Approve from notification** — Accept permission prompts directly without switching windows (sends Enter keystroke via AppleScript)
- **Focus terminal tab** — Jumps to the exact terminal tab running Claude (Terminal.app, iTerm2, Ghostty, WezTerm, VS Code)
- **Discrete sound** — Configurable macOS system sound (default: Purr)
- **Auto-dismiss** — Disappears after 15 seconds

## Requirements

- macOS (Swift compiler, SwiftUI, Cocoa frameworks)
- Python 3 (for transcript context extraction)
- `jq` (for JSON parsing in the shell wrapper)
- **Accessibility permission** for Terminal.app (required for the Approve button — System Settings > Privacy & Security > Accessibility)

## Install

```bash
git clone https://github.com/mfo/claude-accept-dismiss-with-context.git
cd claude-accept-dismiss-with-context
make install
```

Then add the hook to your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/notify.sh"
          }
        ]
      }
    ]
  }
}
```

## Uninstall

```bash
make uninstall
```

## Configuration

Edit `claude-notify.swift` and rebuild:

```swift
let soundName = "Purr"              // Alternatives: "Tink", "Pop", "Glass", "Submarine"
let autoDismissSeconds: Double = 15 // Auto-dismiss delay
let panelWidth: CGFloat = 400       // Notification width
```

```bash
make clean && make install
```

## How it works

1. Claude Code fires the `Notification` hook when it needs user input (permission prompts, etc.)
2. `notify.sh` captures the TTY, extracts conversation context from the transcript, and launches the Swift binary
3. The SwiftUI panel displays the notification with context and action buttons
4. **Approve** focuses the terminal tab and sends an Enter keystroke via AppleScript to accept the permission
5. **Focus** activates the correct terminal tab via AppleScript

## Supported terminals

| Terminal      | Focus tab | Notes                          |
|---------------|-----------|--------------------------------|
| Terminal.app  | ✅        | Matches by TTY                 |
| iTerm2        | ✅        | Matches by ITERM_SESSION_ID    |
| Ghostty       | ⚠️        | Activates app (no tab API)     |
| WezTerm       | ⚠️        | Activates app (no tab API)     |
| VS Code       | ⚠️        | Activates app                  |

## License

MIT
