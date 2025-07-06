#!/usr/bin/env swift

import Foundation
import AppKit
import ScreenCaptureKit

// MARK: - Data Structures

struct WindowInfo: Codable {
    let id: CGWindowID
    let name: String
    let ownerName: String
    let bundleIdentifier: String?
    let frame: CGRect
    let isOnScreen: Bool
    let layer: Int
}

struct DisplayInfo: Codable {
    let id: CGDirectDisplayID
    let name: String
    let frame: CGRect
    let scaleFactor: Float
}

struct ScreenCaptureResponse: Codable {
    let success: Bool
    let message: String
    let windows: [WindowInfo]?
    let displays: [DisplayInfo]?
}

// MARK: - ScreenCaptureKit Manager

@available(macOS 12.3, *)
class ScreenCaptureManager {
    
    // MARK: - Window Discovery
    
    func getAvailableWindows() async -> [WindowInfo] {
        do {
            let shareableContent = try await SCShareableContent.current
            
            return shareableContent.windows.compactMap { window in
                // Filter out system windows and focus on app windows
                guard let ownerName = window.owningApplication?.applicationName,
                      let bundleId = window.owningApplication?.bundleIdentifier,
                      window.isOnScreen,
                      !(window.title?.isEmpty ?? true) else {
                    return nil
                }
                
                return WindowInfo(
                    id: window.windowID,
                    name: window.title ?? "",
                    ownerName: ownerName,
                    bundleIdentifier: bundleId,
                    frame: window.frame,
                    isOnScreen: window.isOnScreen,
                    layer: window.windowLayer
                )
            }
        } catch {
            print("Error getting shareable content: \(error)")
            return []
        }
    }
    
    // MARK: - Display Discovery
    
    func getAvailableDisplays() async -> [DisplayInfo] {
        do {
            let shareableContent = try await SCShareableContent.current
            
            return shareableContent.displays.map { display in
                DisplayInfo(
                    id: display.displayID,
                    name: "Display \(display.displayID)",
                    frame: display.frame,
                    scaleFactor: 1.0 // Note: scaleFactor not available in this API version
                )
            }
        } catch {
            print("Error getting displays: \(error)")
            return []
        }
    }
    
    // MARK: - WoW Window Detection
    
    func findWoWWindows() async -> [WindowInfo] {
        let allWindows = await getAvailableWindows()
        
        return allWindows.filter { window in
            let isWoW = window.name.localizedCaseInsensitiveContains("World of Warcraft") ||
                       window.ownerName.localizedCaseInsensitiveContains("World of Warcraft") ||
                       window.bundleIdentifier?.localizedCaseInsensitiveContains("worldofwarcraft") == true ||
                       window.bundleIdentifier?.localizedCaseInsensitiveContains("battle.net") == true
            
            return isWoW
        }
    }
    
    // MARK: - Screen Capture Setup
    
    func validateWindowForCapture(windowID: CGWindowID) async -> Bool {
        do {
            let shareableContent = try await SCShareableContent.current
            let window = shareableContent.windows.first { $0.windowID == windowID }
            
            guard let targetWindow = window else {
                return false
            }
            
            // Check if window is suitable for capture
            return targetWindow.isOnScreen && 
                   targetWindow.frame.width > 100 && 
                   targetWindow.frame.height > 100
        } catch {
            print("Error validating window: \(error)")
            return false
        }
    }
    
    func getScreenCaptureConfiguration(for windowID: CGWindowID) async -> [String: Any]? {
        do {
            let shareableContent = try await SCShareableContent.current
            guard let window = shareableContent.windows.first(where: { $0.windowID == windowID }) else {
                return nil
            }
            
            return [
                "windowID": windowID,
                "width": Int(window.frame.width),
                "height": Int(window.frame.height),
                "title": window.title ?? "",
                "ownerName": window.owningApplication?.applicationName ?? "Unknown",
                "bundleIdentifier": window.owningApplication?.bundleIdentifier ?? ""
            ]
        } catch {
            print("Error getting screen capture configuration: \(error)")
            return nil
        }
    }
}

// MARK: - Command Line Interface

@available(macOS 12.3, *)
class CommandLineInterface {
    let manager = ScreenCaptureManager()
    
    func handleCommand(_ args: [String]) async {
        guard args.count > 1 else {
            await printUsage()
            return
        }
        
        let command = args[1]
        
        switch command {
        case "--list-windows":
            await listWindows()
        case "--list-displays":
            await listDisplays()
        case "--find-wow":
            await findWoWWindows()
        case "--validate-window":
            if args.count > 2, let windowID = CGWindowID(args[2]) {
                await validateWindow(windowID)
            } else {
                print("Error: --validate-window requires a window ID")
            }
        case "--get-config":
            if args.count > 2, let windowID = CGWindowID(args[2]) {
                await getConfiguration(windowID)
            } else {
                print("Error: --get-config requires a window ID")
            }
        case "--help", "-h":
            await printUsage()
        default:
            print("Error: Unknown command '\(command)'")
            await printUsage()
        }
    }
    
    func listWindows() async {
        let windows = await manager.getAvailableWindows()
        let response = ScreenCaptureResponse(
            success: true,
            message: "Found \(windows.count) windows",
            windows: windows,
            displays: nil
        )
        await printJSON(response)
    }
    
    func listDisplays() async {
        let displays = await manager.getAvailableDisplays()
        let response = ScreenCaptureResponse(
            success: true,
            message: "Found \(displays.count) displays",
            windows: nil,
            displays: displays
        )
        await printJSON(response)
    }
    
    func findWoWWindows() async {
        let wowWindows = await manager.findWoWWindows()
        let response = ScreenCaptureResponse(
            success: true,
            message: "Found \(wowWindows.count) WoW windows",
            windows: wowWindows,
            displays: nil
        )
        await printJSON(response)
    }
    
    func validateWindow(_ windowID: CGWindowID) async {
        let isValid = await manager.validateWindowForCapture(windowID: windowID)
        let response = ScreenCaptureResponse(
            success: isValid,
            message: isValid ? "Window is valid for capture" : "Window is not suitable for capture",
            windows: nil,
            displays: nil
        )
        await printJSON(response)
    }
    
    func getConfiguration(_ windowID: CGWindowID) async {
        if let config = await manager.getScreenCaptureConfiguration(for: windowID) {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            } catch {
                print("Error serializing configuration: \(error)")
            }
        } else {
            let response = ScreenCaptureResponse(
                success: false,
                message: "Could not get configuration for window ID \(windowID)",
                windows: nil,
                displays: nil
            )
            await printJSON(response)
        }
    }
    
    func printJSON<T: Codable>(_ object: T) async {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(object)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } catch {
            print("Error encoding JSON: \(error)")
        }
    }
    
    func printUsage() async {
        let usage = """
        Screen Capture Utility for WoW Recorder
        
        Usage: screen-capture [command] [options]
        
        Commands:
          --list-windows      List all available windows
          --list-displays     List all available displays
          --find-wow          Find World of Warcraft windows
          --validate-window   <id>  Validate if window ID is suitable for capture
          --get-config        <id>  Get screen capture configuration for window ID
          --help, -h          Show this help message
        
        Examples:
          screen-capture --find-wow
          screen-capture --validate-window 12345
          screen-capture --get-config 12345
        """
        print(usage)
    }
}

// MARK: - Main Entry Point

@available(macOS 12.3, *)
func main() async {
    let cli = CommandLineInterface()
    await cli.handleCommand(CommandLine.arguments)
}

// Check macOS version and run
if #available(macOS 12.3, *) {
    Task {
        await main()
    }
    
    // Keep the program running for async operations
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 5))
} else {
    print("Error: This tool requires macOS 12.3 or later for ScreenCaptureKit support")
    exit(1)
}