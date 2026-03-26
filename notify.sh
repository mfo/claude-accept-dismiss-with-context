#!/bin/bash
# Claude Code notification hook - wrapper for compiled Swift notifier

# Debug: log that hook fired
date >> /tmp/claude-notify-hook.log

# Read stdin once (hook payload JSON)
INPUT=$(cat)

# Get the tty of the parent process (claude code's terminal tab)
CLAUDE_TTY="/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')"
export CLAUDE_TTY

# Extract notification type
CLAUDE_NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // empty' 2>/dev/null)
export CLAUDE_NOTIFICATION_TYPE

# Extract transcript path and conversation context
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -n "$TRANSCRIPT" ]; then
    CONTEXT=$(python3 /Users/mfo/.claude/hooks/extract-context.py "$TRANSCRIPT" 2>/dev/null)
    export CLAUDE_CONTEXT="$CONTEXT"
fi

echo "$INPUT" | /Users/mfo/.claude/hooks/claude-notify 2>/tmp/claude-notify-stderr.log &
# Don't block the hook - let the notification run in background
disown
exit 0
