PREFIX ?= $(HOME)/.claude/hooks

.PHONY: build install uninstall clean

build: claude-notify

claude-notify: claude-notify.swift
	swiftc -o claude-notify claude-notify.swift -framework Cocoa -framework SwiftUI

install: build
	mkdir -p $(PREFIX)
	cp claude-notify $(PREFIX)/claude-notify
	cp notify.sh $(PREFIX)/notify.sh
	cp extract-context.py $(PREFIX)/extract-context.py
	chmod +x $(PREFIX)/notify.sh $(PREFIX)/extract-context.py
	@echo ""
	@echo "Installed to $(PREFIX)"
	@echo ""
	@echo "Add this to your ~/.claude/settings.json:"
	@echo ""
	@echo '  "hooks": {'
	@echo '    "Notification": ['
	@echo '      {'
	@echo '        "matcher": "",'
	@echo '        "hooks": ['
	@echo '          {'
	@echo '            "type": "command",'
	@echo '            "command": "$(PREFIX)/notify.sh"'
	@echo '          }'
	@echo '        ]'
	@echo '      }'
	@echo '    ]'
	@echo '  }'

uninstall:
	rm -f $(PREFIX)/claude-notify
	rm -f $(PREFIX)/notify.sh
	rm -f $(PREFIX)/extract-context.py

clean:
	rm -f claude-notify
