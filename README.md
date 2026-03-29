# Typeless Auto Submit

Talk to Claude Code with your voice — no typing, no Enter key.

Press Fn to start dictating, press Fn again to stop. Your message auto-submits.

## Quick Start

### Prerequisites

- macOS 13+ (Apple Silicon or Intel)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed
- [Ghostty](https://ghostty.org/) terminal (see [Other Terminals](#other-terminals) for alternatives)
- macOS Dictation enabled: **System Settings > Keyboard > Dictation > On**
- Xcode Command Line Tools:
  ```bash
  xcode-select --install
  ```

### Step 1: Clone the repo

```bash
git clone https://github.com/AllenHu0829/typeless-auto-submit.git
cd typeless-auto-submit
```

### Step 2: Compile and install

```bash
mkdir -p ~/.claude/hooks
swiftc -o ~/.claude/hooks/dictation-auto-submit \
  dictation-auto-submit.swift \
  -framework IOKit -framework Foundation -framework CoreGraphics
```

### Step 3: Grant macOS permissions

Open **System Settings > Privacy & Security** and add `~/.claude/hooks/dictation-auto-submit`:

1. **Input Monitoring** — to detect Fn key presses
2. **Accessibility** — to send Enter keystroke to terminal

> Tip: drag the binary from Finder, or click `+` and press `Cmd+Shift+G` to type the path.

### Step 4: Enable voice mode

```bash
touch ~/.claude/voice-enabled
```

### Step 5: Run

```bash
~/.claude/hooks/dictation-auto-submit &
```

### Step 6: Test it

1. Open Claude Code in Ghostty
2. Press **Fn** — macOS dictation starts (microphone icon appears)
3. Speak your message
4. Press **Fn** again — dictation stops
5. Wait 2.5 seconds — message auto-submits!

## Auto-Start on Login (Optional)

Set it up so you never have to manually start it:

```bash
cp com.claude.dictation-auto-submit.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.claude.dictation-auto-submit.plist
```

> **Note:** The binary path in the plist is `/Users/allenhu/.claude/hooks/dictation-auto-submit`. Edit the plist to match your home directory:
> ```bash
> sed -i '' "s|/Users/allenhu|$HOME|g" ~/Library/LaunchAgents/com.claude.dictation-auto-submit.plist
> ```

The service auto-restarts on crash and starts on every login.

## On / Off Switch

| Action | Command |
|--------|---------|
| Turn ON | `touch ~/.claude/voice-enabled` |
| Turn OFF | `rm ~/.claude/voice-enabled` |

When OFF, the process still runs but won't send Enter — you can dictate text without auto-submitting.

## How It Works

```
Fn (press)          Fn (press)              Enter sent
    |                   |                       |
    v                   v                       v
[Dictation starts] [Dictation stops]  [2.5s delay] [Auto-submit]
                   [Text inserted into Claude Code input]
```

1. A background process monitors the Fn/Globe key via macOS IOKit HID API
2. First Fn press = dictation started (state tracking)
3. Second Fn press = dictation ended, schedules Enter after 2.5s delay
4. Enter is sent via `osascript` as a physical key code to the terminal process
5. Two Enter events are sent: first commits any IME composing text, second submits the message

## Other Terminals

The default target is Ghostty. To use with a different terminal, edit `dictation-auto-submit.swift`:

Find:
```swift
tell process "ghostty"
```

Replace `ghostty` with your terminal:
| Terminal | Process Name |
|----------|-------------|
| Ghostty | `ghostty` |
| Terminal.app | `Terminal` |
| iTerm2 | `iTerm2` |
| Warp | `Warp` |
| Kitty | `kitty` |
| Alacritty | `alacritty` |

Then recompile (Step 2). After recompiling, re-authorize in Input Monitoring.

## Tuning the Delay

The default 2.5s delay works well for most dictation lengths. Adjust in the source:

```swift
DispatchQueue.global().asyncAfter(deadline: .now() + 2.5) {
```

| Delay | Trade-off |
|-------|-----------|
| 1.5s | Faster, but long dictations may not finish inserting |
| 2.5s | Recommended — reliable for most use cases |
| 3.5s | Very safe, but feels slow |

## Commands Reference

```bash
# View live logs
tail -f /tmp/dictation-auto-submit.log

# Check if running
ps aux | grep dictation-auto-submit | grep -v grep

# Stop manually
pkill -f dictation-auto-submit

# launchd status
launchctl list | grep dictation

# Stop launchd service
launchctl unload ~/Library/LaunchAgents/com.claude.dictation-auto-submit.plist

# Restart launchd service
launchctl unload ~/Library/LaunchAgents/com.claude.dictation-auto-submit.plist
launchctl load ~/Library/LaunchAgents/com.claude.dictation-auto-submit.plist
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `ERROR: Failed to open HID manager` | Add binary to **Input Monitoring** in System Settings |
| Enter sent but message not submitted | Check terminal process name; try increasing delay |
| Fn key not detected | Enable macOS Dictation: System Settings > Keyboard > Dictation |
| launchd service won't start | Re-authorize binary in Input Monitoring after recompile |
| Unstable auto-submit | Increase delay to 3.0s or 3.5s |
| Works in terminal but not via launchd | The binary needs its own Input Monitoring permission (separate from terminal) |

## Files

```
dictation-auto-submit.swift              # Source code
dictation-auto-submit                    # Pre-compiled binary (arm64)
com.claude.dictation-auto-submit.plist   # launchd auto-start config
README.md                                # This file
```

## License

MIT
