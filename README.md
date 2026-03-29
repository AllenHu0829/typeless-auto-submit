# Typeless Auto Submit

Hands-free voice interaction for Claude Code — speak to ask, hear the answer.

- **Voice Input**: Press Fn to dictate, press Fn again — message auto-submits
- **Voice Output**: Claude Code's response is read aloud via macOS TTS

No typing. No Enter key. Just talk.

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

### Step 2: Install scripts

```bash
mkdir -p ~/.claude/hooks

# Compile the auto-submit binary
swiftc -o ~/.claude/hooks/dictation-auto-submit \
  dictation-auto-submit.swift \
  -framework IOKit -framework Foundation -framework CoreGraphics

# Install voice response and toggle scripts
cp voice-response.sh ~/.claude/hooks/
cp voice-toggle.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/voice-response.sh ~/.claude/hooks/voice-toggle.sh
```

### Step 3: Configure Claude Code hook

Add the voice response hook to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/voice-response.sh",
            "async": true
          }
        ]
      }
    ]
  }
}
```

> If you already have a `settings.json`, merge the `hooks` section into your existing config.

### Step 4: Grant macOS permissions

Open **System Settings > Privacy & Security** and add `~/.claude/hooks/dictation-auto-submit`:

1. **Input Monitoring** — to detect Fn key presses
2. **Accessibility** — to send Enter keystroke to terminal

> Tip: click `+` and press `Cmd+Shift+G` to type the path.

### Step 5: Enable and run

```bash
# Enable voice mode
touch ~/.claude/voice-enabled

# Start the auto-submit listener
~/.claude/hooks/dictation-auto-submit &
```

### Step 6: Test it

1. Open Claude Code in Ghostty
2. Press **Fn** — macOS dictation starts (microphone icon appears)
3. Speak your message
4. Press **Fn** again — dictation stops
5. Wait 2.5s — message auto-submits
6. Claude responds — response is read aloud

## Voice Control

Use `voice-toggle.sh` to manage all voice features:

```bash
# Quick toggle on/off
bash ~/.claude/hooks/voice-toggle.sh on
bash ~/.claude/hooks/voice-toggle.sh off

# Check current status
bash ~/.claude/hooks/voice-toggle.sh status

# Change TTS voice
bash ~/.claude/hooks/voice-toggle.sh voice Tingting    # Chinese
bash ~/.claude/hooks/voice-toggle.sh voice Samantha    # English
bash ~/.claude/hooks/voice-toggle.sh voice Meijia      # Chinese (Taiwan)

# Adjust speech speed (words per minute)
bash ~/.claude/hooks/voice-toggle.sh rate 180          # Slower
bash ~/.claude/hooks/voice-toggle.sh rate 220          # Default
bash ~/.claude/hooks/voice-toggle.sh rate 280          # Faster

# Stop speaking immediately
bash ~/.claude/hooks/voice-toggle.sh stop
```

> Tip: add an alias to your `.zshrc`:
> ```bash
> alias voice="bash ~/.claude/hooks/voice-toggle.sh"
> ```
> Then use: `voice on`, `voice off`, `voice status`, etc.

## Available macOS Voices

List all installed voices:

```bash
say -v '?'
```

Common voices:

| Voice | Language | Notes |
|-------|----------|-------|
| Tingting | Chinese (Mandarin) | Default |
| Sinji | Chinese (Cantonese) | |
| Meijia | Chinese (Taiwan) | |
| Samantha | English (US) | |
| Daniel | English (UK) | |

Download more in **System Settings > Accessibility > Spoken Content > System Voice > Manage Voices**.

## Auto-Start on Login (Optional)

```bash
# Copy and customize the plist
cp com.claude.dictation-auto-submit.plist ~/Library/LaunchAgents/
sed -i '' "s|/Users/allenhu|$HOME|g" ~/Library/LaunchAgents/com.claude.dictation-auto-submit.plist

# Load the service
launchctl load ~/Library/LaunchAgents/com.claude.dictation-auto-submit.plist
```

The service auto-restarts on crash and starts on every login.

## How It Works

```
┌─────────────── Voice Input ───────────────┐   ┌──────── Voice Output ────────┐
│                                           │   │                              │
│  Fn → Dictate → Fn → [2.5s] → Auto Enter │ → │  Claude responds → TTS aloud │
│                                           │   │                              │
└───────────────────────────────────────────┘   └──────────────────────────────┘
```

**Voice Input (dictation-auto-submit)**:
1. Background process monitors Fn/Globe key via macOS IOKit HID API
2. First Fn press = dictation started
3. Second Fn press = dictation ended, schedules Enter after 2.5s
4. Enter sent via `osascript key code 36` to the terminal process
5. Two Enter events: first commits IME text, second submits message

**Voice Output (voice-response.sh)**:
1. Claude Code `Stop` hook triggers after each response
2. Script extracts text, strips code blocks/tables/URLs/paths
3. Condenses to key sentences (max 300 chars)
4. Reads aloud via macOS `say` command
5. Previous speech is interrupted if new response arrives

## Other Terminals

Default target is Ghostty. Edit `dictation-auto-submit.swift` to change:

```swift
tell process "ghostty"   // ← replace with your terminal
```

| Terminal | Process Name |
|----------|-------------|
| Ghostty | `ghostty` |
| Terminal.app | `Terminal` |
| iTerm2 | `iTerm2` |
| Warp | `Warp` |
| Kitty | `kitty` |
| Alacritty | `alacritty` |

Recompile after editing (Step 2). Re-authorize in Input Monitoring after recompile.

## Tuning

### Auto-submit delay

Edit `dictation-auto-submit.swift`:

```swift
DispatchQueue.global().asyncAfter(deadline: .now() + 2.5) {
```

| Delay | Trade-off |
|-------|-----------|
| 1.5s | Faster, may miss long dictation text |
| 2.5s | Recommended |
| 3.5s | Very safe, feels slow |

### TTS response length

Edit `voice-response.sh`, change max lines and character limit:

```bash
# Take first 3 key lines
key_lines[:3]

# Hard limit
if len(condensed) > 300:
```

## Commands Reference

```bash
# Voice toggle
bash ~/.claude/hooks/voice-toggle.sh status

# View auto-submit logs
tail -f /tmp/dictation-auto-submit.log

# Check if auto-submit is running
pgrep -x dictation-auto-submit

# Stop auto-submit
pkill -x dictation-auto-submit

# Stop TTS immediately
pkill -f "say -v"

# launchd control
launchctl list | grep dictation
launchctl unload ~/Library/LaunchAgents/com.claude.dictation-auto-submit.plist
launchctl load ~/Library/LaunchAgents/com.claude.dictation-auto-submit.plist
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `ERROR: Failed to open HID manager` | Add binary to **Input Monitoring** in System Settings |
| Enter sent but message not submitted | Check terminal process name; try increasing delay |
| Fn key not detected | Enable macOS Dictation: System Settings > Keyboard > Dictation |
| launchd won't start | Re-authorize binary in Input Monitoring after recompile |
| Unstable auto-submit | Increase delay to 3.0s or 3.5s |
| No voice response | Check `~/.claude/settings.json` has the Stop hook configured |
| Wrong language voice | Run `voice-toggle.sh voice <name>` to change |
| Voice too fast/slow | Run `voice-toggle.sh rate <wpm>` to adjust |

## Files

```
dictation-auto-submit.swift              # Auto-submit source code
dictation-auto-submit                    # Pre-compiled binary (arm64)
voice-response.sh                        # TTS response hook for Claude Code
voice-toggle.sh                          # Voice mode control script
com.claude.dictation-auto-submit.plist   # launchd auto-start config
flow-comparison.svg                      # Flow comparison diagram
README.md                                # This file
```

## License

MIT
