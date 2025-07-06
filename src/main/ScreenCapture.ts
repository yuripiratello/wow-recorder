/**
 * macOS Screen Capture Bridge
 * 
 * This module provides a bridge between the Node.js/Electron application
 * and the native macOS ScreenCaptureKit Swift utilities.
 */

import { exec } from 'child_process';
import { promisify } from 'util';
import path from 'path';
import { app } from 'electron';

const execAsync = promisify(exec);

// Types matching the Swift utilities
export interface WindowInfo {
  id: number;
  name: string;
  ownerName: string;
  bundleIdentifier?: string;
  frame: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  isOnScreen: boolean;
  layer: number;
}

export interface DisplayInfo {
  id: number;
  name: string;
  frame: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  scaleFactor: number;
}

export interface ProcessInfo {
  pid: number;
  name: string;
  bundleIdentifier?: string;
  isActive: boolean;
  isWoW: boolean;
  wowVersion?: string;
  launchDate?: Date;
}

export interface ScreenCaptureResponse {
  success: boolean;
  message: string;
  windows?: WindowInfo[];
  displays?: DisplayInfo[];
}

export interface ProcessDetectionResponse {
  success: boolean;
  message: string;
  processes: ProcessInfo[];
  wowProcessCount: number;
}

export class MacOSScreenCapture {
  private screenCaptureBinary: string;
  private wowDetectorBinary: string;

  constructor() {
    // Get the path to our Swift utilities
    const resourcesPath = app.isPackaged
      ? path.join(process.resourcesPath, 'binaries', 'macos')
      : path.join(__dirname, '../../binaries/macos');

    this.screenCaptureBinary = path.join(resourcesPath, 'screen-capture');
    this.wowDetectorBinary = path.join(resourcesPath, 'wow-detector');
  }

  // MARK: - Window Discovery

  /**
   * Get all available windows that can be captured
   */
  async getAvailableWindows(): Promise<WindowInfo[]> {
    try {
      const { stdout } = await execAsync(`"${this.screenCaptureBinary}" --list-windows`);
      const response: ScreenCaptureResponse = JSON.parse(stdout);
      return response.windows || [];
    } catch (error) {
      console.error('[MacOSScreenCapture] Failed to get windows:', error);
      return [];
    }
  }

  /**
   * Get all available displays
   */
  async getAvailableDisplays(): Promise<DisplayInfo[]> {
    try {
      const { stdout } = await execAsync(`"${this.screenCaptureBinary}" --list-displays`);
      const response: ScreenCaptureResponse = JSON.parse(stdout);
      return response.displays || [];
    } catch (error) {
      console.error('[MacOSScreenCapture] Failed to get displays:', error);
      return [];
    }
  }

  /**
   * Find World of Warcraft windows specifically
   */
  async findWoWWindows(): Promise<WindowInfo[]> {
    try {
      const { stdout } = await execAsync(`"${this.screenCaptureBinary}" --find-wow`);
      const response: ScreenCaptureResponse = JSON.parse(stdout);
      return response.windows || [];
    } catch (error) {
      console.error('[MacOSScreenCapture] Failed to find WoW windows:', error);
      return [];
    }
  }

  /**
   * Validate if a window is suitable for capture
   */
  async validateWindow(windowId: number): Promise<boolean> {
    try {
      const { stdout } = await execAsync(`"${this.screenCaptureBinary}" --validate-window ${windowId}`);
      const response: ScreenCaptureResponse = JSON.parse(stdout);
      return response.success;
    } catch (error) {
      console.error('[MacOSScreenCapture] Failed to validate window:', error);
      return false;
    }
  }

  /**
   * Get screen capture configuration for a specific window
   */
  async getWindowConfiguration(windowId: number): Promise<any> {
    try {
      const { stdout } = await execAsync(`"${this.screenCaptureBinary}" --get-config ${windowId}`);
      return JSON.parse(stdout);
    } catch (error) {
      console.error('[MacOSScreenCapture] Failed to get window configuration:', error);
      return null;
    }
  }

  // MARK: - Process Detection

  /**
   * Detect all WoW-related processes
   */
  async detectWoWProcesses(): Promise<ProcessInfo[]> {
    try {
      const { stdout } = await execAsync(`"${this.wowDetectorBinary}" --find-wow`);
      const response: ProcessDetectionResponse = JSON.parse(stdout);
      return response.processes || [];
    } catch (error) {
      console.error('[MacOSScreenCapture] Failed to detect WoW processes:', error);
      return [];
    }
  }

  /**
   * Check if WoW is currently running
   */
  async isWoWRunning(): Promise<boolean> {
    try {
      const { stdout } = await execAsync(`"${this.wowDetectorBinary}" --is-running`);
      const response: ProcessDetectionResponse = JSON.parse(stdout);
      return response.success && response.wowProcessCount > 0;
    } catch (error) {
      console.error('[MacOSScreenCapture] Failed to check if WoW is running:', error);
      return false;
    }
  }

  /**
   * Get the currently active WoW process
   */
  async getActiveWoWProcess(): Promise<ProcessInfo | null> {
    try {
      const { stdout } = await execAsync(`"${this.wowDetectorBinary}" --active`);
      const response: ProcessDetectionResponse = JSON.parse(stdout);
      return response.processes?.[0] || null;
    } catch (error) {
      console.error('[MacOSScreenCapture] Failed to get active WoW process:', error);
      return null;
    }
  }

  // MARK: - Integration Helpers

  /**
   * Find the best WoW window for recording
   * Prioritizes active game windows over launcher windows
   */
  async findBestWoWWindow(): Promise<WindowInfo | null> {
    try {
      const wowWindows = await this.findWoWWindows();
      
      if (wowWindows.length === 0) {
        return null;
      }

      // Sort by preference: larger windows first, then by name
      const sortedWindows = wowWindows.sort((a, b) => {
        // Prefer actual game windows over launcher/setup windows
        const aIsGame = !a.name.toLowerCase().includes('launcher') && 
                       !a.name.toLowerCase().includes('setup') &&
                       !a.name.toLowerCase().includes('login');
        const bIsGame = !b.name.toLowerCase().includes('launcher') && 
                       !b.name.toLowerCase().includes('setup') &&
                       !b.name.toLowerCase().includes('login');

        if (aIsGame && !bIsGame) return -1;
        if (!aIsGame && bIsGame) return 1;

        // Prefer larger windows
        const aArea = a.frame.width * a.frame.height;
        const bArea = b.frame.width * b.frame.height;
        return bArea - aArea;
      });

      // Validate the best window
      const bestWindow = sortedWindows[0];
      const isValid = await this.validateWindow(bestWindow.id);
      
      return isValid ? bestWindow : null;
    } catch (error) {
      console.error('[MacOSScreenCapture] Failed to find best WoW window:', error);
      return null;
    }
  }

  /**
   * Get window information that can be used with OBS
   * Returns data in a format compatible with OBS window capture
   */
  async getOBSWindowInfo(windowId: number): Promise<{
    windowId: number;
    windowName: string;
    ownerName: string;
    bundleId: string;
    frame: { width: number; height: number; x: number; y: number };
  } | null> {
    try {
      const config = await this.getWindowConfiguration(windowId);
      if (!config) return null;

      return {
        windowId: config.windowID,
        windowName: config.title || 'Unknown Window',
        ownerName: config.ownerName || 'Unknown Application',
        bundleId: config.bundleIdentifier || '',
        frame: {
          width: config.width || 0,
          height: config.height || 0,
          x: 0, // ScreenCaptureKit doesn't provide position in this context
          y: 0
        }
      };
    } catch (error) {
      console.error('[MacOSScreenCapture] Failed to get OBS window info:', error);
      return null;
    }
  }

  // MARK: - Utility Methods

  /**
   * Check if screen recording permissions are granted
   * This is a best-effort check based on error messages
   */
  async hasScreenRecordingPermission(): Promise<boolean> {
    try {
      await this.getAvailableWindows();
      return true;
    } catch (error) {
      const errorMessage = error.toString().toLowerCase();
      return !errorMessage.includes('tcc') && 
             !errorMessage.includes('permission') && 
             !errorMessage.includes('declined');
    }
  }

  /**
   * Get a human-readable status of the screen capture system
   */
  async getStatus(): Promise<{
    hasPermission: boolean;
    wowRunning: boolean;
    wowWindowsFound: number;
    bestWindow?: WindowInfo;
  }> {
    const hasPermission = await this.hasScreenRecordingPermission();
    const wowRunning = await this.isWoWRunning();
    
    let wowWindowsFound = 0;
    let bestWindow: WindowInfo | undefined;

    if (hasPermission) {
      const wowWindows = await this.findWoWWindows();
      wowWindowsFound = wowWindows.length;
      bestWindow = await this.findBestWoWWindow() || undefined;
    }

    return {
      hasPermission,
      wowRunning,
      wowWindowsFound,
      bestWindow
    };
  }
}