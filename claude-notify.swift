import Cocoa
import SwiftUI

// MARK: - Config
let soundName = "Purr" // Discret. Alternatives: "Tink", "Pop", "Glass", "Submarine"
let autoDismissSeconds: Double = 15
let panelWidth: CGFloat = 400

// MARK: - Read input
func getMessage() -> String {
    if CommandLine.arguments.count > 1 {
        return CommandLine.arguments[1]
    }
    if let data = try? FileHandle.standardInput.availableData,
       !data.isEmpty,
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let message = json["message"] as? String {
        return message
    }
    return "Claude needs your attention"
}

func getNotificationType() -> String {
    let env = ProcessInfo.processInfo.environment
    return env["CLAUDE_NOTIFICATION_TYPE"] ?? ""
}

func getTty() -> String? {
    let env = ProcessInfo.processInfo.environment
    if let tty = env["CLAUDE_TTY"], !tty.isEmpty {
        return tty
    }
    return nil
}

func sendToTty(_ text: String) {
    guard let tty = getTty() else { return }
    guard let fh = FileHandle(forWritingAtPath: tty) else { return }
    if let data = text.data(using: .utf8) {
        fh.write(data)
    }
    fh.closeFile()
}

func getContext() -> String? {
    let env = ProcessInfo.processInfo.environment
    if let context = env["CLAUDE_CONTEXT"], !context.isEmpty {
        return context
    }
    return nil
}

// MARK: - Terminal focus (specific tab)
func buildFocusScript() -> String {
    let env = ProcessInfo.processInfo.environment
    let termProgram = env["TERM_PROGRAM"] ?? ""

    switch termProgram {
    case "iTerm.app":
        if let sessionId = env["ITERM_SESSION_ID"] {
            let parts = sessionId.split(separator: ":")
            if parts.first != nil {
                return """
                tell application "iTerm2"
                    activate
                    repeat with w in windows
                        repeat with t in tabs of w
                            repeat with s in sessions of t
                                if unique ID of s contains "\(sessionId)" then
                                    select t
                                    return
                                end if
                            end repeat
                        end repeat
                    end repeat
                end tell
                """
            }
        }
        return """
        tell application "iTerm2" to activate
        """

    case "ghostty":
        return """
        tell application "Ghostty" to activate
        """

    case "WezTerm":
        return """
        tell application "WezTerm" to activate
        """

    case "vscode":
        return """
        tell application "Visual Studio Code" to activate
        """

    case "Apple_Terminal":
        if let tty = env["CLAUDE_TTY"], !tty.isEmpty {
            return """
            tell application "Terminal"
                activate
                repeat with w in windows
                    repeat with t in tabs of w
                        if tty of t contains "\(tty)" then
                            set selected tab of w to t
                            set index of w to 1
                            return
                        end if
                    end repeat
                end repeat
            end tell
            """
        }
        return """
        tell application "Terminal" to activate
        """

    default:
        return """
        tell application "Terminal" to activate
        """
    }
}

// MARK: - Context line view
struct ContextLineView: View {
    let role: String
    let text: String

    var isUser: Bool { role == "You" }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(role)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(isUser ? .orange : Color(red: 0.56, green: 0.47, blue: 0.94))
                .frame(width: 42, alignment: .trailing)

            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.75))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - SwiftUI Notification View
struct NotificationView: View {
    let message: String
    let context: String?
    let isPermissionPrompt: Bool
    let onApprove: () -> Void
    let onFocus: () -> Void
    let onDismiss: () -> Void

    var contextLines: [(role: String, text: String)] {
        guard let ctx = context else { return [] }
        return ctx.components(separatedBy: "\n").compactMap { line in
            if line.hasPrefix("You: ") {
                return ("You", String(line.dropFirst(5)))
            } else if line.hasPrefix("Claude: ") {
                return ("Claude", String(line.dropFirst(8)))
            }
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.linearGradient(
                        colors: [Color(red: 0.56, green: 0.47, blue: 0.94),
                                 Color(red: 0.35, green: 0.28, blue: 0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Claude Code")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(message)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, contextLines.isEmpty ? 0 : 10)

            // Context (conversation history)
            if !contextLines.isEmpty {
                Divider()
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(contextLines.enumerated()), id: \.offset) { _, line in
                        ContextLineView(role: line.role, text: line.text)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            // Buttons
            HStack(spacing: 8) {
                Spacer()

                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.08))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Button(action: onFocus) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 11))
                        Text("Focus")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.56, green: 0.47, blue: 0.94))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                if isPermissionPrompt {
                    Button(action: onApprove) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                            Text("Approve")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .frame(width: panelWidth)
        .background(
            VisualEffectView()
                .clipShape(RoundedRectangle(cornerRadius: 14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 8)
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}

// MARK: - NSVisualEffectView wrapper
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Panel controller
class NotificationPanelController {
    var panel: NSPanel?
    var autoDismissTimer: Timer?
    let focusScript: String

    init(focusScript: String) {
        self.focusScript = focusScript
    }

    func show(message: String, context: String?, isPermissionPrompt: Bool) {
        let contentView = NotificationView(
            message: message,
            context: context,
            isPermissionPrompt: isPermissionPrompt,
            onApprove: { [weak self] in
                sendToTty("y\n")
                self?.dismiss()
            },
            onFocus: { [weak self] in
                self?.focusTerminal()
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: contentView)
        let fittingSize = hostingView.fittingSize

        // Position: top-right corner with margin
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelFrame = NSRect(
            x: screenFrame.maxX - panelWidth - 16,
            y: screenFrame.maxY - fittingSize.height - 8,
            width: panelWidth,
            height: fittingSize.height
        )

        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.contentView = hostingView
        panel.alphaValue = 0

        self.panel = panel

        // Animate in
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        // Play sound
        if let sound = NSSound(named: NSSound.Name(soundName)) {
            sound.play()
        }

        // Auto-dismiss
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismissSeconds, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    func focusTerminal() {
        let script = NSAppleScript(source: focusScript)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
    }

    func dismiss() {
        autoDismissTimer?.invalidate()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel?.animator().alphaValue = 0
        }, completionHandler: {
            self.panel?.close()
            NSApplication.shared.terminate(nil)
        })
    }
}

// MARK: - App delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    let controller: NotificationPanelController
    let message: String
    let context: String?
    let isPermissionPrompt: Bool

    init(controller: NotificationPanelController, message: String, context: String?, isPermissionPrompt: Bool) {
        self.controller = controller
        self.message = message
        self.context = context
        self.isPermissionPrompt = isPermissionPrompt
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.show(message: message, context: context, isPermissionPrompt: isPermissionPrompt)
    }
}

// MARK: - Main
let message = getMessage()
let context = getContext()
let notificationType = getNotificationType()
let isPermissionPrompt = notificationType == "permission_prompt"
let focusScript = buildFocusScript()
let controller = NotificationPanelController(focusScript: focusScript)
let delegate = AppDelegate(controller: controller, message: message, context: context, isPermissionPrompt: isPermissionPrompt)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
