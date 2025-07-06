/**
 * Platform-specific OBS Studio Node loader
 * 
 * This module handles loading the correct OBS Studio Node binary
 * based on the current platform (Windows or macOS).
 */

import * as path from 'path';
import { platform } from 'os';

// Type definitions for obs-studio-node
export * from 'obs-studio-node';

/**
 * Dynamically loads the appropriate OBS Studio Node module
 * based on the current platform
 */
function loadObsModule() {
  const currentPlatform = platform();
  
  try {
    switch (currentPlatform) {
      case 'win32':
        // Try to load Windows-specific OBS module
        try {
          // Use dynamic import to avoid webpack bundling issues
          return eval('require("obs-studio-node-win32")');
        } catch (winError) {
          console.warn('[OBS Loader] Windows-specific OBS module not found, falling back to default');
          // Fallback to existing Windows module
          return require('obs-studio-node');
        }
        
      case 'darwin':
        // Try to load macOS-specific OBS module
        try {
          // Use dynamic import to avoid webpack bundling issues
          return eval('require("obs-studio-node-darwin")');
        } catch (macError) {
          console.warn('[OBS Loader] macOS-specific OBS module not found, falling back to default');
          // For now, fallback to the Windows module for testing
          // This will be replaced with proper macOS binaries later
          try {
            return require('obs-studio-node');
          } catch (fallbackError) {
            throw new Error(`OBS Studio Node not available for macOS. Please install obs-studio-node-darwin dependency. Error: ${fallbackError.message}`);
          }
        }
        
      default:
        throw new Error(`Unsupported platform: ${currentPlatform}. Only Windows and macOS are supported.`);
    }
  } catch (error) {
    console.error('[OBS Loader] Failed to load OBS Studio Node:', error);
    throw error;
  }
}

// Export the dynamically loaded OBS module
const obsModule = loadObsModule();

// Re-export all OBS functionality
export const NodeObs = obsModule.NodeObs;
export const InputFactory = obsModule.InputFactory;
export const FilterFactory = obsModule.FilterFactory;
export const TransitionFactory = obsModule.TransitionFactory;
export const SceneFactory = obsModule.SceneFactory;
export const VolmeterFactory = obsModule.VolmeterFactory;
export const FaderFactory = obsModule.FaderFactory;
export const VideoFactory = obsModule.VideoFactory;
export const AudioFactory = obsModule.AudioFactory;
export const OutputFactory = obsModule.OutputFactory;
export const ServiceFactory = obsModule.ServiceFactory;
export const ModuleFactory = obsModule.ModuleFactory;
export const Global = obsModule.Global;

// Export types
export type {
  IFader,
  IInput,
  IScene,
  ISceneItem,
  ISource,
  ITransition,
  IFilter,
  IVolmeter,
  IVideo,
  IAudio,
  IOutput,
  IService,
  IModule,
  ICallbackData,
  ISettings,
  IProperty,
  ITimeSpec,
  IVec2,
  IDisplay,
  IObsInput,
  IObsOutput,
  IObsService,
  IObsScene,
  IObsSceneItem,
  IObsFilter,
  IObsTransition,
  IObsVolmeter,
  IObsFader,
  IObsVideo,
  IObsAudio,
  IObsSource,
  IObsModule,
  IObsGlobal,
  IObsDisplay,
  IObsCallback,
  IObsProperty,
  IObsSettings,
  IObsTimeSpec,
  IObsVec2,
  IObsData,
  IObsSourceInfo,
  IObsOutputInfo,
  IObsServiceInfo,
  IObsSceneInfo,
  IObsSceneItemInfo,
  IObsFilterInfo,
  IObsTransitionInfo,
  IObsVolmeterInfo,
  IObsFaderInfo,
  IObsVideoInfo,
  IObsAudioInfo,
  IObsModuleInfo,
  IObsGlobalInfo,
  IObsDisplayInfo,
  IObsCallbackInfo,
  IObsPropertyInfo,
  IObsSettingsInfo,
  IObsTimeSpecInfo,
  IObsVec2Info,
  IObsDataInfo
} from 'obs-studio-node';

export default obsModule;