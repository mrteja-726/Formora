import Cocoa
import FlutterMacOS
import ApplicationServices

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Formora Accessibility & Autofill Method Channel Setup
    let channel = FlutterMethodChannel(name: "formora/autofill", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "isAccessibilityTrusted" {
        result(AXIsProcessTrusted())
      } else if call.method == "getFocusedElement" {
        result(self?.getFocusedElementDetails())
      } else if call.method == "triggerAutofill" {
        guard let args = call.arguments as? [String: Any],
              let value = args["value"] as? String else {
          result(FlutterError(code: "BAD_ARGS", message: "Missing parameter 'value'", details: nil))
          return
        }
        result(self?.setFocusedElementValue(value))
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  private func getFocusedElementDetails() -> [String: Any] {
    var result: [String: Any] = ["success": false]
    let systemElement = AXUIElementCreateSystemWide()
    
    var focusedElement: AnyObject?
    let status = AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
    
    guard status == .success, let element = focusedElement else {
      return result
    }
    
    let axElement = element as! AXUIElement
    result["success"] = true
    
    // Role
    var role: AnyObject?
    if AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &role) == .success, let roleStr = role as? String {
      result["role"] = roleStr
    }
    
    // Title / Name
    var title: AnyObject?
    if AXUIElementCopyAttributeValue(axElement, kAXTitleAttribute as CFString, &title) == .success, let titleStr = title as? String {
      result["name"] = titleStr
    }
    
    // Identifier / Description
    var identifier: AnyObject?
    if AXUIElementCopyAttributeValue(axElement, "AXIdentifier" as CFString, &identifier) == .success, let idStr = identifier as? String {
      result["id"] = idStr
    } else {
      var description: AnyObject?
      if AXUIElementCopyAttributeValue(axElement, kAXDescriptionAttribute as CFString, &description) == .success, let descStr = description as? String {
        result["id"] = descStr
      }
    }
    
    return result
  }

  private func setFocusedElementValue(_ value: String) -> Bool {
    let systemElement = AXUIElementCreateSystemWide()
    
    var focusedElement: AnyObject?
    let status = AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
    
    guard status == .success, let element = focusedElement else {
      return false
    }
    
    let axElement = element as! AXUIElement
    
    // Try AXValue injection
    let nsValue = value as CFTypeRef
    let setStatus = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, nsValue)
    if setStatus == .success {
      return true
    }
    
    // Fallback: keystroke simulation using CGEvent
    let source = CGEventSource(stateID: .combinedSessionState)
    
    // Cmd+A (virtualKey 0x00 is 'a', maskCommand is CMD flag)
    let cmdADown = CGEvent(keyboardEventSource: source, virtualKey: 0x00, keyDown: true)
    cmdADown?.flags = .maskCommand
    let cmdAUp = CGEvent(keyboardEventSource: source, virtualKey: 0x00, keyDown: false)
    cmdAUp?.flags = .maskCommand
    
    cmdADown?.post(tap: .cghidEventTap)
    cmdAUp?.post(tap: .cghidEventTap)
    
    Thread.sleep(forTimeInterval: 0.05)
    
    // Backspace (virtualKey 0x33 is delete/backspace)
    let backspaceDown = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true)
    let backspaceUp = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false)
    
    backspaceDown?.post(tap: .cghidEventTap)
    backspaceUp?.post(tap: .cghidEventTap)
    
    Thread.sleep(forTimeInterval: 0.05)
    
    // Type characters
    for char in value {
      let chars = Array(String(char).utf16)
      let eventDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
      eventDown?.keyboardGetUnicodeString(maxStringLength: chars.count, actualStringLength: nil, unicodeString: UnsafeMutablePointer(mutating: chars))
      let eventUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
      eventUp?.keyboardGetUnicodeString(maxStringLength: chars.count, actualStringLength: nil, unicodeString: UnsafeMutablePointer(mutating: chars))
      
      eventDown?.post(tap: .cghidEventTap)
      eventUp?.post(tap: .cghidEventTap)
    }
    
    return true
  }
}
