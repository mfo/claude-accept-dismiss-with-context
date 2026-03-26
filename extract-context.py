#!/usr/bin/env python3
"""Extract last conversation context from Claude Code transcript for notifications."""
import json
import sys

def extract_context(transcript_path, max_chars=300):
    messages = []
    try:
        with open(transcript_path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except (json.JSONDecodeError, ValueError):
                    continue

                t = obj.get('type')
                if t not in ('user', 'assistant'):
                    continue

                msg = obj.get('message', {})
                content = msg.get('content', '')
                texts = []
                if isinstance(content, str) and content.strip():
                    texts = [content.strip()]
                elif isinstance(content, list):
                    for item in content:
                        if isinstance(item, dict) and item.get('type') == 'text':
                            text = item['text'].strip()
                            if text:
                                texts.append(text)

                if texts:
                    combined = ' '.join(texts)
                    # Skip system reminders and tool results
                    if '<system-reminder>' in combined or combined.startswith('Exit code'):
                        continue
                    messages.append({
                        'role': 'You' if t == 'user' else 'Claude',
                        'text': combined
                    })
    except (FileNotFoundError, PermissionError):
        pass

    # Get last user message and last assistant message
    last_user = None
    last_assistant = None
    for m in reversed(messages):
        if m['role'] == 'You' and not last_user:
            last_user = m['text']
        elif m['role'] == 'Claude' and not last_assistant:
            last_assistant = m['text']
        if last_user and last_assistant:
            break

    lines = []
    if last_user:
        truncated = last_user[:120] + ('…' if len(last_user) > 120 else '')
        lines.append(f"You: {truncated}")
    if last_assistant:
        truncated = last_assistant[:180] + ('…' if len(last_assistant) > 180 else '')
        lines.append(f"Claude: {truncated}")

    return '\n'.join(lines) if lines else ''

if __name__ == '__main__':
    # Read hook payload from stdin or first argument
    transcript_path = None
    if len(sys.argv) > 1:
        transcript_path = sys.argv[1]
    else:
        try:
            payload = json.loads(sys.stdin.read())
            transcript_path = payload.get('transcript_path')
        except (json.JSONDecodeError, ValueError):
            pass

    if transcript_path:
        print(extract_context(transcript_path))
