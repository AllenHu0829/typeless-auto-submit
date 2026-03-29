import Cocoa
import Foundation
import IOKit
import IOKit.hid
import CoreGraphics

let gFlagFile = NSString(string: "~/.claude/voice-enabled").expandingTildeInPath
var gDictationActive = false
var gLastFnDownTime: TimeInterval = 0
let kDedupeWindow: TimeInterval = 0.05  // ignore duplicate FN events within 50ms
var gLastHIDEventTime: TimeInterval = 0 // track last HID event for watchdog
let kWatchdogInterval: TimeInterval = 60 // check every 60 seconds
let kWatchdogTimeout: TimeInterval = 300 // reconnect if no events for 5 minutes
var gManager: IOHIDManager?

func log(_ msg: String) {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    let ts = f.string(from: Date())
    let line = "[\(ts)] \(msg)\n"
    FileHandle.standardError.write(line.data(using: .utf8)!)
}

func sendEnter() {
    guard FileManager.default.fileExists(atPath: gFlagFile) else {
        log("Voice mode off, skipping Enter")
        return
    }

    // Use osascript key code 36 (physical Return key) targeted at Ghostty
    // Send twice: 1st commits IME, 2nd submits message
    for i in 1...2 {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", """
            tell application "System Events"
                tell process "ghostty"
                    key code 36
                end tell
            end tell
            """]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                log(">>> Enter #\(i) SENT (key code 36 → ghostty)")
            } else {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let err = String(data: data, encoding: .utf8) ?? ""
                log("ERROR: osascript #\(i) failed: \(err)")
            }
        } catch {
            log("ERROR: osascript #\(i) exception: \(error)")
        }

        if i == 1 {
            usleep(500000) // 500ms gap between the two Enters
        }
    }
}

// HID callback
let hidCallback: IOHIDValueCallback = { context, result, sender, value in
    let element = IOHIDValueGetElement(value)
    let usagePage = IOHIDElementGetUsagePage(element)
    let usage = IOHIDElementGetUsage(element)
    let intValue = IOHIDValueGetIntegerValue(value)

    // Track last event time for watchdog
    gLastHIDEventTime = ProcessInfo.processInfo.systemUptime

    // Log all keyboard events for debugging
    if usagePage == 0x07 || usagePage == 0x01 || usagePage == 0x0C || usagePage == 0xFF {
        log("HID: page=0x\(String(usagePage, radix: 16)) usage=0x\(String(usage, radix: 16)) value=\(intValue)")
    }

    // Fn/Globe key can appear as:
    // - Usage page 0x01 (Generic Desktop), usage 0x06 (Keyboard) with modifier
    // - Usage page 0x07 (Keyboard), usage 0xE8 or similar
    // - Usage page 0xFF (Apple vendor), various usages
    // - Usage page 0x0C (Consumer), usage 0xCF (Dictation)
    // - Usage page 0x01, usage 0xC6 (system keyboard)

    let isFnKey =
        (usagePage == 0x0C && usage == 0xCF) ||   // Consumer: Voice Dictation
        (usagePage == 0xFF && usage == 0x03) ||    // Apple vendor: Fn
        (usagePage == 0xFF && usage == 0x04) ||    // Apple vendor: Globe
        (usagePage == 0x07 && usage == 0xE8) ||    // Keyboard: Fn (some devices)
        (usagePage == 0x01 && usage == 0x00C6)     // Generic Desktop: System Keyboard

    if isFnKey {
        if intValue == 1 { // Key down
            // Deduplicate: two HID devices report the same FN press
            let now = ProcessInfo.processInfo.systemUptime
            if now - gLastFnDownTime < kDedupeWindow {
                log("    (duplicate FN down, ignored)")
                return
            }
            gLastFnDownTime = now

            log(">>> FN/Globe KEY DOWN detected!")
            if !gDictationActive {
                gDictationActive = true
                log(">>> Dictation STARTED (FN press)")
            } else {
                gDictationActive = false
                log(">>> Dictation ENDED (FN press), sending Enter in 2.5s...")
                DispatchQueue.global().asyncAfter(deadline: .now() + 2.5) {
                    sendEnter()
                }
            }
        } else if intValue == 0 { // Key up
            log("    FN/Globe key up")
        }
    }
}

// --- HID Manager Setup ---
func createAndOpenHIDManager() -> IOHIDManager {
    let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

    let matchingDicts: [[String: Any]] = [
        [
            kIOHIDDeviceUsagePageKey as String: 0x01,
            kIOHIDDeviceUsageKey as String: 0x06
        ],
        [
            kIOHIDDeviceUsagePageKey as String: 0x01,
            kIOHIDDeviceUsageKey as String: 0x07
        ],
        [
            kIOHIDDeviceUsagePageKey as String: 0x0C,
            kIOHIDDeviceUsageKey as String: 0x01
        ]
    ]

    IOHIDManagerSetDeviceMatchingMultiple(mgr, matchingDicts as CFArray)
    IOHIDManagerRegisterInputValueCallback(mgr, hidCallback, nil)
    IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

    let result = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
    if result != kIOReturnSuccess {
        log("ERROR: Failed to open HID manager (result: \(result))")
        log("Make sure Input Monitoring permission is granted:")
        log("  System Settings > Privacy & Security > Input Monitoring")
        exit(1)
    }

    return mgr
}

func reconnectHID() {
    log(">>> WATCHDOG: Reconnecting HID manager...")

    // Close old manager
    if let old = gManager {
        IOHIDManagerClose(old, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(old, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    // Create new manager
    gManager = createAndOpenHIDManager()
    gLastHIDEventTime = ProcessInfo.processInfo.systemUptime
    gDictationActive = false
    log(">>> WATCHDOG: HID manager reconnected successfully")
}

// --- Main ---
log("Dictation auto-submit active (PID \(ProcessInfo.processInfo.processIdentifier))")
log("Using IOHIDManager for low-level key capture...")

gManager = createAndOpenHIDManager()
gLastHIDEventTime = ProcessInfo.processInfo.systemUptime

log("HID manager opened successfully. Listening for key events...")
log("Watchdog: checking every \(Int(kWatchdogInterval))s, reconnect if silent for \(Int(kWatchdogTimeout))s")
log("Press FN key to test detection.")

// Watchdog timer: reconnect HID if no events received for too long
let watchdogTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
watchdogTimer.schedule(deadline: .now() + kWatchdogInterval, repeating: kWatchdogInterval)
watchdogTimer.setEventHandler {
    let now = ProcessInfo.processInfo.systemUptime
    let silent = now - gLastHIDEventTime
    if silent > kWatchdogTimeout {
        log(">>> WATCHDOG: No HID events for \(Int(silent))s, triggering reconnect...")
        DispatchQueue.main.async {
            reconnectHID()
        }
    }
}
watchdogTimer.resume()

signal(SIGINT) { _ in log("Stopped."); exit(0) }
signal(SIGTERM) { _ in exit(0) }

CFRunLoopRun()
