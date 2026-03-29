# Dictation Auto-Submit for Claude Code

Press Fn to dictate, press Fn again to stop — message auto-submits. No need to press Enter.

## How It Works

1. Fn (1st press) — macOS dictation starts recording
2. Fn (2nd press) — dictation stops, text is inserted
3. After 2.5s delay, Enter is automatically sent to submit the message

## Requirements

- macOS (Apple Silicon / Intel)
- Ghostty terminal (hardcoded in osascript target; edit source for other terminals)
- Claude Code CLI running in Ghostty
- Xcode Command Line Tools (`xcode-select --install`)

## Installation

### 1. Compile the binary

```bash
swiftc -o ~/.claude/hooks/dictation-auto-submit \
  dictation-auto-submit.swift \
  -framework IOKit -framework Foundation -framework CoreGraphics
```

### 2. Grant permissions

Open **System Settings > Privacy & Security** and add the compiled binary to:

- **Input Monitoring** — required to detect Fn key via HID
- **Accessibility** — required for osascript to send keystrokes

The binary path is `~/.claude/hooks/dictation-auto-submit`.

### 3. Enable voice mode

```bash
touch ~/.claude/voice-enabled
```

### 4. Test manually

```bash
~/.claude/hooks/dictation-auto-submit > /tmp/dictation-debug.log 2>&1 &
```

Open Claude Code in Ghostty, press Fn to dictate, press Fn again to stop. The message should auto-submit after 2.5 seconds.

Check the log for troubleshooting:

```bash
tail -f /tmp/dictation-debug.log
```

### 5. Set up auto-start (launchd)

Copy the plist to LaunchAgents:

```bash
cp com.claude.dictation-auto-submit.plist ~/Library/LaunchAgents/
```

Load the service:

```bash
launchctl load ~/Library/LaunchAgents/com.claude.dictation-auto-submit.plist
```

The service will auto-start on login and restart on crash.

## Usage

| Action | Command |
|--------|---------|
| Enable voice auto-submit | `touch ~/.claude/voice-enabled` |
| Disable voice auto-submit | `rm ~/.claude/voice-enabled` |
| Check status | `launchctl list \| grep dictation` |
| View logs | `tail -f /tmp/dictation-auto-submit.log` |
| Stop service | `launchctl unload ~/Library/LaunchAgents/com.claude.dictation-auto-submit.plist` |
| Restart service | `launchctl unload ... && launchctl load ...` |

## Customization

### Change target terminal

Edit `dictation-auto-submit.swift`, find `tell process "ghostty"` and replace `ghostty` with your terminal name (e.g., `Terminal`, `iTerm2`, `Warp`).

### Adjust delay

Edit the delay value in the source (default 2.5 seconds):

```swift
DispatchQueue.global().asyncAfter(deadline: .now() + 2.5) {
```

Shorter = faster submit but may fire before dictation text is fully inserted.
Longer = more reliable but slower response.

### Recompile after changes

```bash
swiftc -o ~/.claude/hooks/dictation-auto-submit \
  ~/.claude/hooks/dictation-auto-submit.swift \
  -framework IOKit -framework Foundation -framework CoreGraphics
```

**Note:** After recompiling, you must re-authorize the binary in System Settings > Input Monitoring.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `ERROR: Failed to open HID manager` | Grant Input Monitoring permission in System Settings |
| Enter sent but message not submitted | Increase the delay (try 3.0s) or check terminal target name |
| FN key not detected | Check if macOS dictation is enabled: System Settings > Keyboard > Dictation |
| Service won't start via launchd | Re-authorize binary in Input Monitoring after recompile |

## Files

```
dictation-auto-submit.swift              # Source code
dictation-auto-submit                    # Compiled binary (arm64)
com.claude.dictation-auto-submit.plist   # launchd auto-start config
```
