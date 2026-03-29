#!/bin/bash
# Toggle Claude Code voice response on/off
# Usage: voice-toggle.sh [on|off|status|voice <name>|rate <wpm>|stop]

FLAG_FILE="$HOME/.claude/voice-enabled"
VOICE_FILE="$HOME/.claude/voice-name"
RATE_FILE="$HOME/.claude/voice-rate"

case "${1:-toggle}" in
    on)
        touch "$FLAG_FILE"
        # Start dictation auto-submit if not running
        if ! pgrep -x "dictation-auto-submit" > /dev/null 2>&1; then
            nohup "$HOME/.claude/hooks/dictation-auto-submit" \
                > /tmp/dictation-auto-submit.log 2>&1 &
            echo "Voice mode: ON (auto-submit started, PID $!)"
        else
            echo "Voice mode: ON (auto-submit already running)"
        fi
        ;;
    off)
        rm -f "$FLAG_FILE"
        pkill -f "say -v" 2>/dev/null
        pkill -x "dictation-auto-submit" 2>/dev/null
        echo "Voice mode: OFF (auto-submit stopped)"
        ;;
    toggle)
        if [ -f "$FLAG_FILE" ]; then
            rm -f "$FLAG_FILE"
            pkill -f "say -v" 2>/dev/null
            echo "Voice mode: OFF"
        else
            touch "$FLAG_FILE"
            echo "Voice mode: ON"
        fi
        ;;
    status)
        if [ -f "$FLAG_FILE" ]; then
            echo "Voice mode: ON"
        else
            echo "Voice mode: OFF"
        fi
        if pgrep -x "dictation-auto-submit" > /dev/null 2>&1; then
            echo "Auto-submit: running"
        else
            echo "Auto-submit: stopped"
        fi
        VOICE=$(cat "$VOICE_FILE" 2>/dev/null || echo "Tingting")
        RATE=$(cat "$RATE_FILE" 2>/dev/null || echo "220")
        echo "Voice: $VOICE"
        echo "Rate: $RATE wpm"
        ;;
    voice)
        if [ -z "$2" ]; then
            echo "Usage: voice-toggle.sh voice <name>"
            echo "Examples: Tingting (zh_CN), Samantha (en_US), Meijia (zh_TW)"
            exit 1
        fi
        echo -n "$2" > "$VOICE_FILE"
        echo "Voice set to: $2"
        ;;
    rate)
        if [ -z "$2" ]; then
            echo "Usage: voice-toggle.sh rate <words-per-minute>"
            echo "Default: 220, Range: 100-400"
            exit 1
        fi
        echo -n "$2" > "$RATE_FILE"
        echo "Rate set to: $2 wpm"
        ;;
    stop)
        pkill -f "say -v" 2>/dev/null
        echo "Stopped speaking"
        ;;
    *)
        echo "Usage: voice-toggle.sh [on|off|toggle|status|voice <name>|rate <wpm>|stop]"
        ;;
esac
