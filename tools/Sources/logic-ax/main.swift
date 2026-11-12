import AppKit
import ApplicationServices
import Foundation

// logic-ax: examine and operate Logic Pro UI elements through the macOS Accessibility API.
// An element address is a path of child indexes from the application element, for example 0.3.12.

let usage = """
logic-ax: Accessibility tool for Logic Pro

Usage:
  logic-ax trusted                         Show if this process has Accessibility permission
  logic-ax windows                         List the windows
  logic-ax dump <path|-> <depth> [regex]   Show the tree below a path. With a regex, show only matches.
  logic-ax get <path>                      Show all attributes and actions of one element
  logic-ax press <path>                    Do the AXPress action
  logic-ax action <path> <AXAction>        Do a named action
  logic-ax set <path> <value>              Set AXValue (number or text)
  logic-ax focus <path>                    Set AXFocused to true
  logic-ax tune <path> <number>            Move a slider until its readout (AXValueDescription) is nearest to the number
  logic-ax menu <path> <item> [<item>...]  Press an element, then select items in the menu that opens
Options:
  --bundle <id>   Target application (default com.apple.mobilelogic, then com.apple.logic10)
"""

var args = Array(CommandLine.arguments.dropFirst())
var bundleIDs = ["com.apple.mobilelogic", "com.apple.logic10"]
if let i = args.firstIndex(of: "--bundle"), i + 1 < args.count {
    bundleIDs = [args[i + 1]]
    args.removeSubrange(i...(i + 1))
}

func fail(_ s: String) -> Never {
    FileHandle.standardError.write(Data("error: \(s)\n".utf8))
    exit(1)
}

func attr(_ e: AXUIElement, _ name: String) -> AnyObject? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
}

func text(_ v: AnyObject?, max: Int = 90) -> String {
    guard let v else { return "" }
    var s: String
    if let str = v as? String { s = str } else if let n = v as? NSNumber { s = n.stringValue } else { return "" }
    s = s.replacingOccurrences(of: "\n", with: " ")
    return s.count > max ? String(s.prefix(max)) + "…" : s
}

func children(_ e: AXUIElement) -> [AXUIElement] {
    (attr(e, kAXChildrenAttribute as String) as? [AXUIElement]) ?? []
}

func actions(_ e: AXUIElement) -> [String] {
    var names: CFArray?
    guard AXUIElementCopyActionNames(e, &names) == .success, let list = names as? [String] else { return [] }
    return list
}

func describe(_ e: AXUIElement) -> String {
    let role = text(attr(e, kAXRoleAttribute as String))
    let sub = text(attr(e, kAXSubroleAttribute as String))
    var parts = [sub.isEmpty ? role : "\(role)/\(sub)"]
    for (label, key) in [("title", kAXTitleAttribute as String), ("desc", kAXDescriptionAttribute as String),
                         ("value", kAXValueAttribute as String), ("help", kAXHelpAttribute as String),
                         ("id", kAXIdentifierAttribute as String), ("roledesc", kAXRoleDescriptionAttribute as String)] {
        let t = text(attr(e, key))
        if !t.isEmpty { parts.append("\(label)=\"\(t)\"") }
    }
    let acts = actions(e).map { $0.replacingOccurrences(of: "AX", with: "") }
    if !acts.isEmpty { parts.append("[" + acts.joined(separator: ",") + "]") }
    return parts.joined(separator: " ")
}

func appElement() -> AXUIElement {
    for id in bundleIDs {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first {
            let e = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(e, 3.0)
            return e
        }
    }
    fail("Logic Pro is not in operation")
}

func resolve(_ path: String) -> AXUIElement {
    var e = appElement()
    if path == "-" || path.isEmpty { return e }
    for part in path.split(separator: ".") {
        if part.hasPrefix("@") {
            // "@text" selects the window whose title contains the text. Window indexes change, titles do not.
            let want = String(part.dropFirst())
            guard let w = children(e).first(where: { text(attr($0, kAXRoleAttribute as String)) == "AXWindow" && text(attr($0, kAXTitleAttribute as String)).contains(want) }) else { fail("no window with title \(want)") }
            e = w
            continue
        }
        guard let i = Int(part) else { fail("incorrect path \(path)") }
        let c = children(e)
        guard i >= 0, i < c.count else { fail("no child \(i) at \(part) in path \(path) (count \(c.count))") }
        e = c[i]
    }
    return e
}

var visited = 0
func dump(_ e: AXUIElement, path: String, depth: Int, maxDepth: Int, regex: NSRegularExpression?) {
    visited += 1
    if visited > 40000 { return }
    let line = describe(e)
    let show = regex == nil || regex!.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
    if show {
        let indent = regex == nil ? String(repeating: "  ", count: depth) : ""
        print("\(indent)\(path.isEmpty ? "-" : path)  \(line)")
    }
    guard depth < maxDepth else { return }
    for (i, c) in children(e).enumerated() {
        dump(c, path: path.isEmpty ? "\(i)" : "\(path).\(i)", depth: depth + 1, maxDepth: maxDepth, regex: regex)
    }
}

guard let cmd = args.first else { print(usage); exit(2) }

switch cmd {
case "trusted":
    print(AXIsProcessTrusted() ? "trusted" : "not trusted")
case "windows":
    for (i, w) in children(appElement()).enumerated() { print("\(i)  \(describe(w))") }
case "dump":
    guard args.count >= 3, let depth = Int(args[2]) else { fail("dump <path|-> <depth> [regex]") }
    let regex = args.count > 3 ? try? NSRegularExpression(pattern: args[3], options: [.caseInsensitive]) : nil
    let start = args[1] == "-" ? "" : args[1]
    dump(resolve(args[1]), path: start, depth: 0, maxDepth: depth, regex: regex)
    if visited > 40000 { print("(stopped at 40000 elements)") }
case "get":
    guard args.count >= 2 else { fail("get <path>") }
    let e = resolve(args[1])
    var names: CFArray?
    AXUIElementCopyAttributeNames(e, &names)
    for n in (names as? [String]) ?? [] {
        let v = attr(e, n)
        var t = text(v, max: 200)
        if t.isEmpty, let v { t = String(describing: v).replacingOccurrences(of: "\n", with: " "); t = String(t.prefix(160)) }
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(e, n as CFString, &settable)
        print("\(n)\(settable.boolValue ? " (settable)" : ""): \(t)")
    }
    print("actions: \(actions(e).joined(separator: ", "))")
case "press", "action":
    guard args.count >= 2 else { fail("\(cmd) <path>") }
    let name = cmd == "press" ? (kAXPressAction as String) : (args.count > 2 ? args[2] : "")
    let r = AXUIElementPerformAction(resolve(args[1]), name as CFString)
    print(r == .success ? "ok" : "error \(r.rawValue)")
    exit(r == .success ? 0 : 1)
case "set":
    guard args.count >= 3 else { fail("set <path> <value>") }
    let value: AnyObject = Double(args[2]).map { NSNumber(value: $0) } ?? (args[2] as NSString)
    let r = AXUIElementSetAttributeValue(resolve(args[1]), kAXValueAttribute as CFString, value)
    print(r == .success ? "ok" : "error \(r.rawValue)")
    exit(r == .success ? 0 : 1)
case "focus":
    guard args.count >= 2 else { fail("focus <path>") }
    let r = AXUIElementSetAttributeValue(resolve(args[1]), kAXFocusedAttribute as CFString, kCFBooleanTrue)
    print(r == .success ? "ok" : "error \(r.rawValue)")
case "tune":
    // Logic Pro moves a slider only one step for each AXValue write. Thus this command steps until the readout agrees.
    guard args.count >= 3, let target = Double(args[2]) else { fail("tune <path> <number>") }
    let e = resolve(args[1])
    func raw() -> Double { (attr(e, kAXValueAttribute as String) as? NSNumber)?.doubleValue ?? .nan }
    func readout() -> String { text(attr(e, kAXValueDescriptionAttribute as String)) }
    func number(_ s: String) -> Double? {
        let t = s.replacingOccurrences(of: "\u{2212}", with: "-")
        guard let r = t.range(of: "[-+]?[0-9]*\\.?[0-9]+", options: .regularExpression), var v = Double(t[r]) else { return nil }
        if t.contains("kHz") { v *= 1000 }
        return v
    }
    func write(_ v: Double) -> Bool {
        let before = raw()
        guard AXUIElementSetAttributeValue(e, kAXValueAttribute as CFString, NSNumber(value: v)) == .success else { return false }
        for _ in 0..<50 where raw() == before { usleep(2000) }
        return raw() != before
    }
    let lo = (attr(e, kAXMinValueAttribute as String) as? NSNumber)?.doubleValue ?? -Double.infinity
    let hi = (attr(e, kAXMaxValueAttribute as String) as? NSNumber)?.doubleValue ?? Double.infinity
    guard var v = number(readout()) else { fail("no numeric readout: \(readout())") }
    let dir: Double = v < target ? 1 : -1
    var steps = 0
    var previous = v
    while steps < 4000, (dir > 0 && v < target) || (dir < 0 && v > target) {
        let next = raw() + dir
        if next < lo || next > hi || !write(next) { break }
        previous = v
        guard let n = number(readout()) else { break }
        v = n
        steps += 1
    }
    if steps > 0, abs(previous - target) < abs(v - target), write(raw() - dir) { steps += 1 }
    print("\(readout()) (raw \(Int(raw())), \(steps) steps)")
case "menu":
    guard args.count >= 3 else { fail("menu <path> <item> [<item>...]") }
    let e = resolve(args[1])
    // Logic Pro opens pop-up menus only when it is the active application.
    for id in bundleIDs { NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.activate(options: []) }
    usleep(400_000)
    // A press that opens a menu can stop until the menu closes. Thus a timeout result is not an error here.
    AXUIElementSetMessagingTimeout(e, 0.6)
    let pressResult = AXUIElementPerformAction(e, kAXPressAction as CFString)
    if pressResult != .success && pressResult != .cannotComplete { fail("press failed: \(pressResult.rawValue)") }
    func role(_ x: AXUIElement) -> String { text(attr(x, kAXRoleAttribute as String)) }
    func findMenu(_ root: AXUIElement, depth: Int) -> AXUIElement? {
        if role(root) == "AXMenu" { return root }
        guard depth > 0 else { return nil }
        for c in children(root) { if let m = findMenu(c, depth: depth - 1) { return m } }
        return nil
    }
    func openMenu() -> AXUIElement? {
        let app = appElement()
        // An open menu is usually the focused element of the application.
        if let f = attr(app, kAXFocusedUIElementAttribute as String) {
            let fe = f as! AXUIElement
            if role(fe) == "AXMenu" { return fe }
            if role(fe) == "AXMenuItem", let parent = attr(fe, kAXParentAttribute as String) { return (parent as! AXUIElement) }
        }
        if let m = findMenu(e, depth: 2) { return m }
        for c in children(app) where role(c) != "AXMenuBar" { if let m = findMenu(c, depth: 2) { return m } }
        return nil
    }
    var found: AXUIElement?
    for _ in 0..<20 {
        usleep(100_000)
        if let m = openMenu() { found = m; break }
    }
    guard var menu = found else { fail("no menu opened (press result \(pressResult.rawValue))") }
    for (n, name) in args.dropFirst(2).enumerated() {
        let items = children(menu)
        guard let item = items.first(where: { text(attr($0, kAXTitleAttribute as String)) == name })
                ?? items.first(where: { text(attr($0, kAXTitleAttribute as String)).localizedCaseInsensitiveContains(name) }) else {
            let titles = items.map { text(attr($0, kAXTitleAttribute as String)) }.filter { !$0.isEmpty }
            AXUIElementPerformAction(menu, kAXCancelAction as CFString)
            fail("no menu item \"\(name)\". Items: \(titles.joined(separator: " | "))")
        }
        guard AXUIElementPerformAction(item, kAXPressAction as CFString) == .success else { fail("cannot select \(name)") }
        if n < args.count - 3 {
            usleep(350_000)
            guard let sub = children(item).first(where: { text(attr($0, kAXRoleAttribute as String)) == "AXMenu" }) else { fail("no submenu below \(name)") }
            menu = sub
        }
    }
    print("ok")
default:
    print(usage)
}
