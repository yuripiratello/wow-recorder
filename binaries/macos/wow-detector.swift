#!/usr/bin/env swift

import Foundation
import AppKit

// MARK: - Data Structures

struct ProcessInfo: Codable {
    let pid: Int32
    let name: String
    let bundleIdentifier: String?
    let isActive: Bool
    let isWoW: Bool
    let wowVersion: String?
    let launchDate: Date?
}

struct ProcessDetectionResponse: Codable {
    let success: Bool
    let message: String
    let processes: [ProcessInfo]
    let wowProcessCount: Int
}

// MARK: - WoW Process Detector

class WoWProcessDetector {
    
    // WoW-related identifiers and patterns
    private let wowBundlePatterns = [
        "com.blizzard.worldofwarcraft",
        "battle.net",
        "blizzard"
    ]
    
    private let wowNamePatterns = [
        "World of Warcraft",
        "WoW",
        "Battle.net",
        "Blizzard Battle.net"
    ]
    
    func detectAllProcesses() -> [ProcessInfo] {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        return runningApps.compactMap { app in
            let bundleId = app.bundleIdentifier ?? ""
            let appName = app.localizedName ?? ""
            
            let isWoWApp = isWoWRelated(bundleId: bundleId, appName: appName)
            let wowVersion = determineWoWVersion(bundleId: bundleId, appName: appName)
            
            return ProcessInfo(
                pid: app.processIdentifier,
                name: appName,
                bundleIdentifier: app.bundleIdentifier,
                isActive: app.isActive,
                isWoW: isWoWApp,
                wowVersion: wowVersion,
                launchDate: app.launchDate
            )
        }
    }
    
    func detectWoWProcesses() -> [ProcessInfo] {
        return detectAllProcesses().filter { $0.isWoW }
    }
    
    private func isWoWRelated(bundleId: String, appName: String) -> Bool {
        let bundleLower = bundleId.lowercased()
        let nameLower = appName.lowercased()
        
        // Check bundle identifier patterns
        for pattern in wowBundlePatterns {
            if bundleLower.contains(pattern.lowercased()) {
                return true
            }
        }
        
        // Check application name patterns
        for pattern in wowNamePatterns {
            if nameLower.contains(pattern.lowercased()) {
                return true
            }
        }
        
        return false
    }
    
    private func determineWoWVersion(bundleId: String, appName: String) -> String? {
        let combined = (bundleId + " " + appName).lowercased()
        
        if combined.contains("classic") && combined.contains("era") {
            return "Classic Era"
        } else if combined.contains("classic") {
            return "Classic"
        } else if combined.contains("ptr") || combined.contains("test") {
            return "PTR/Beta"
        } else if combined.contains("world of warcraft") && !combined.contains("classic") {
            return "Retail"
        } else if combined.contains("battle.net") || combined.contains("blizzard") {
            return "Launcher"
        }
        
        return nil
    }
    
    func getActiveWoWProcess() -> ProcessInfo? {
        let wowProcesses = detectWoWProcesses()
        
        // Prioritize active WoW game processes over launcher
        let gameProcesses = wowProcesses.filter { process in
            process.isActive && 
            process.wowVersion != "Launcher" &&
            process.wowVersion != nil
        }
        
        return gameProcesses.first ?? wowProcesses.first(where: { $0.isActive })
    }
    
    func isWoWRunning() -> Bool {
        return !detectWoWProcesses().isEmpty
    }
    
    func getWoWProcessCount() -> Int {
        return detectWoWProcesses().count
    }
}

// MARK: - Command Line Interface

class CommandLineInterface {
    let detector = WoWProcessDetector()
    
    func handleCommand(_ args: [String]) {
        let command = args.count > 1 ? args[1] : "--detect-wow"
        
        switch command {
        case "--detect-wow", "--find-wow":
            detectWoWProcesses()
        case "--list-all":
            listAllProcesses()
        case "--is-running":
            checkIfWoWRunning()
        case "--active":
            getActiveWoWProcess()
        case "--count":
            getWoWProcessCount()
        case "--help", "-h":
            printUsage()
        default:
            print("Error: Unknown command '\(command)'")
            printUsage()
        }
    }
    
    func detectWoWProcesses() {
        let wowProcesses = detector.detectWoWProcesses()
        let response = ProcessDetectionResponse(
            success: true,
            message: "Found \(wowProcesses.count) WoW-related processes",
            processes: wowProcesses,
            wowProcessCount: wowProcesses.count
        )
        printJSON(response)
    }
    
    func listAllProcesses() {
        let allProcesses = detector.detectAllProcesses()
        let wowCount = allProcesses.filter { $0.isWoW }.count
        let response = ProcessDetectionResponse(
            success: true,
            message: "Found \(allProcesses.count) total processes (\(wowCount) WoW-related)",
            processes: allProcesses,
            wowProcessCount: wowCount
        )
        printJSON(response)
    }
    
    func checkIfWoWRunning() {
        let isRunning = detector.isWoWRunning()
        let count = detector.getWoWProcessCount()
        let response = ProcessDetectionResponse(
            success: isRunning,
            message: isRunning ? "WoW is running (\(count) processes)" : "WoW is not running",
            processes: isRunning ? detector.detectWoWProcesses() : [],
            wowProcessCount: count
        )
        printJSON(response)
    }
    
    func getActiveWoWProcess() {
        if let activeProcess = detector.getActiveWoWProcess() {
            let response = ProcessDetectionResponse(
                success: true,
                message: "Found active WoW process: \(activeProcess.name)",
                processes: [activeProcess],
                wowProcessCount: 1
            )
            printJSON(response)
        } else {
            let response = ProcessDetectionResponse(
                success: false,
                message: "No active WoW process found",
                processes: [],
                wowProcessCount: 0
            )
            printJSON(response)
        }
    }
    
    func getWoWProcessCount() {
        let count = detector.getWoWProcessCount()
        let processes = detector.detectWoWProcesses()
        let response = ProcessDetectionResponse(
            success: count > 0,
            message: "\(count) WoW processes detected",
            processes: processes,
            wowProcessCount: count
        )
        printJSON(response)
    }
    
    func printJSON<T: Codable>(_ object: T) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(object)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } catch {
            print("Error encoding JSON: \(error)")
        }
    }
    
    func printUsage() {
        let usage = """
        WoW Process Detector for WoW Recorder
        
        Usage: wow-detector [command]
        
        Commands:
          --detect-wow, --find-wow    Detect WoW-related processes (default)
          --list-all                  List all running processes
          --is-running                Check if WoW is currently running
          --active                    Get the currently active WoW process
          --count                     Get count of WoW processes
          --help, -h                  Show this help message
        
        Output: JSON format with process information
        
        Examples:
          wow-detector                    # Detect WoW processes
          wow-detector --is-running       # Check if WoW is running
          wow-detector --active           # Get active WoW process
        """
        print(usage)
    }
}

// MARK: - Main Entry Point

func main() {
    let cli = CommandLineInterface()
    cli.handleCommand(CommandLine.arguments)
}

// Run the main function
main()