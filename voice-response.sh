#!/bin/bash
# Claude Code Voice Response Hook
# Triggered on Stop event — reads Claude's response aloud via macOS TTS
# Toggle: touch ~/.claude/voice-enabled  (on)
#         rm ~/.claude/voice-enabled     (off)

FLAG_FILE="$HOME/.claude/voice-enabled"

# Exit if voice mode is off
[ -f "$FLAG_FILE" ] || exit 0

# Read the Stop event JSON from stdin
input=$(cat)

# Extract and condense the response text
message=$(echo "$input" | /usr/bin/python3 -c "
import sys, json, re

try:
    data = json.load(sys.stdin)
    msg = data.get('last_assistant_message', '')
    if not msg:
        sys.exit(0)

    # --- Phase 1: Remove non-speech content ---
    # Remove code blocks
    msg = re.sub(r'\`\`\`[\s\S]*?\`\`\`', '', msg)
    # Remove inline code
    msg = re.sub(r'\`[^\`]+\`', '', msg)
    # Remove markdown tables (lines starting with |)
    msg = re.sub(r'^\|.*$', '', msg, flags=re.MULTILINE)
    # Remove horizontal rules
    msg = re.sub(r'^[-*_]{3,}\s*$', '', msg, flags=re.MULTILINE)
    # Remove URLs
    msg = re.sub(r'https?://\S+', '', msg)
    # Remove file paths (like /Users/... or ~/.config/...)
    msg = re.sub(r'[~/][a-zA-Z0-9_./-]{10,}', '', msg)
    # Remove markdown images
    msg = re.sub(r'!\[.*?\]\(.*?\)', '', msg)

    # --- Phase 2: Simplify formatting ---
    # Headers -> just the text
    msg = re.sub(r'^#{1,6}\s+', '', msg, flags=re.MULTILINE)
    # Bold/italic -> just the text
    msg = re.sub(r'\*{1,3}([^*]+)\*{1,3}', r'\1', msg)
    # Links -> just the text
    msg = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', msg)
    # Bullet points -> plain text
    msg = re.sub(r'^\s*[-*+]\s+', '', msg, flags=re.MULTILINE)
    # Numbered lists -> plain text
    msg = re.sub(r'^\s*\d+\.\s+', '', msg, flags=re.MULTILINE)

    # --- Phase 3: Extract key sentences ---
    # Collapse whitespace
    msg = re.sub(r'\n{2,}', '\n', msg)
    lines = [l.strip() for l in msg.split('\n') if l.strip()]

    # Keep only meaningful lines (skip very short fragments and noise)
    key_lines = []
    for line in lines:
        # Skip lines that are mostly punctuation/symbols
        alpha_ratio = sum(1 for c in line if c.isalpha() or '\u4e00' <= c <= '\u9fff') / max(len(line), 1)
        if alpha_ratio < 0.3:
            continue
        # Skip lines that look like commands or technical fragments
        if line.startswith(('$', '>', '#', '//', '/*', 'import ', 'from ', 'def ', 'class ')):
            continue
        key_lines.append(line)

    if not key_lines:
        sys.exit(0)

    # Take first 3 key lines as the condensed summary
    condensed = '。'.join(key_lines[:3]) if any('\u4e00' <= c <= '\u9fff' for c in ''.join(key_lines)) else '. '.join(key_lines[:3])

    # Hard limit for TTS
    if len(condensed) > 300:
        # Cut at last sentence boundary
        for sep in ['。', '. ', '！', '？', '!', '?']:
            pos = condensed.rfind(sep, 0, 300)
            if pos > 50:
                condensed = condensed[:pos+1]
                break
        else:
            condensed = condensed[:300]

    print(condensed)
except Exception:
    sys.exit(0)
" 2>/dev/null)

[ -z "$message" ] && exit 0

# Kill any previous say process to avoid queueing
pkill -f "say -v" 2>/dev/null

# Read voice preference (default: Tingting for Chinese, Samantha for English)
VOICE_FILE="$HOME/.claude/voice-name"
if [ -f "$VOICE_FILE" ]; then
    VOICE=$(cat "$VOICE_FILE" | tr -d '\n')
else
    VOICE="Tingting"
fi

# Read speed preference (default: 220 words/min)
RATE_FILE="$HOME/.claude/voice-rate"
if [ -f "$RATE_FILE" ]; then
    RATE=$(cat "$RATE_FILE" | tr -d '\n')
else
    RATE="220"
fi

# Speak in background so it doesn't block
say -v "$VOICE" -r "$RATE" "$message" &
