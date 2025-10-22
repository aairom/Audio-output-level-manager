//
//  AudioControlAppApp.swift
//  AudioControlApp
//
//  Created by Alain Airom on 20/10/2025.
//

//
// This file demonstrates the structure for a native macOS GUI application using Swift and SwiftUI.
// NOTE: This structure MUST be compiled within an Xcode project to access system frameworks
// like CoreAudio and to create a runnable application bundle (.app).
// It cannot be run as a standalone script or in a web environment.
//

import SwiftUI
import CoreAudio // Required for the underlying device access (would interface with your C++ code)
internal import Combine

// MARK: - Model

/// Represents an audio output device.
struct AudioDevice: Identifiable {
    let id: String // Corresponds to the Device UID
    let name: String
    var isDefault: Bool
    var volume: Double // 0.0 to 1.0 (internal representation)
}

// MARK: - Controller/View Model

/// Manages the application state and audio interactions.
class AudioController: ObservableObject {
    @Published var outputDevices: [AudioDevice] = []
    @Published var selectedDeviceUID: String? = nil
    
    // In a real application, this class would handle the bridge to the C++ Core Audio logic.
    
    init() {
        // Load initial device list when the controller is initialized
        loadDevices()
    }
    
    /// Simulates fetching the list of output devices from the Core Audio API (via a C++ bridge).
    func loadDevices() {
        // --- Placeholder Data ---
        // In a real Xcode project, this function would call the C++ logic
        // to retrieve the actual device list, UIDs, and current volume/default status.
        
        // This simulates the data we saw in the console (note: "Microphone" is typically input,
        // but often appears as an output option for loopback/monitoring, which we include here):
        let defaultUID = "mac-mic-1234"
        
        outputDevices = [
            AudioDevice(id: "mac-mic-1234", name: "Internal Speakers (Default)", isDefault: true, volume: 0.8),
            AudioDevice(id: "zoom-virtual-4567", name: "ZoomAudioDevice (Virtual)", isDefault: false, volume: 0.2),
            AudioDevice(id: "headset-bluetooth-8901", name: "Wireless Headphones", isDefault: false, volume: 1.0)
        ]
        
        selectedDeviceUID = defaultUID
    }
    
    /// Sets the selected device as the system default.
    func setDefaultDevice(uid: String) {
        if let index = outputDevices.firstIndex(where: { $0.id == uid }) {
            // 1. Call C++ function: setSystemDefaultOutputDevice(uid)
            
            // 2. Update local state
            for i in outputDevices.indices {
                outputDevices[i].isDefault = (outputDevices[i].id == uid)
            }
            selectedDeviceUID = uid
            print("Action: Set default to \(outputDevices[index].name)")
        }
    }
    
    /// Sets the volume for the selected device.
    func setVolume(uid: String, volume: Double) {
        if let index = outputDevices.firstIndex(where: { $0.id == uid }) {
            // 1. Call C++ function: setDeviceVolume(uid, volume * 100)
            
            // 2. Update local state
            outputDevices[index].volume = volume
            print("Action: Set volume for \(outputDevices[index].name) to \(Int(volume * 100))%")
        }
    }
}

// MARK: - View

struct ContentView: View {
    @StateObject private var audioController = AudioController()
    
    // Computed property to safely access the currently selected device details
    var selectedDevice: AudioDevice? {
        audioController.outputDevices.first(where: { $0.id == audioController.selectedDeviceUID })
    }
    
    // Use a local state for the slider to ensure smooth, immediate UI response
    @State private var currentVolume: Double = 0.5
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            Text("macOS Audio Output Control")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 5)

            // --- Device Selection Picker ---
            VStack(alignment: .leading) {
                Text("Select Output Device:")
                    .font(.headline)
                
                Picker("Output Device", selection: $audioController.selectedDeviceUID) {
                    ForEach(audioController.outputDevices) { device in
                        HStack {
                            Text(device.name)
                            if device.isDefault {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.teal)
                            }
                        }
                        // Tag must match the type of selectedDeviceUID
                        .tag(device.id as String?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 300)
                .onChange(of: audioController.selectedDeviceUID) { _, newUID in
                    // Sync the local slider value when the selected device changes
                    if let device = audioController.outputDevices.first(where: { $0.id == newUID }) {
                        currentVolume = device.volume
                    }
                }
            }
            
            // --- Current Volume/Controls ---
            if let device = selectedDevice {
                Divider()
                
                Text("Controls for: \(device.name)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                // Volume Slider
                VStack(alignment: .leading, spacing: 10) {
                    Text("Volume: \(Int(currentVolume * 100))%")
                        .font(.body)
                    
                    Slider(value: $currentVolume, in: 0...1.0) {
                        Text("Volume Slider")
                    } onEditingChanged: { isEditing in
                        if !isEditing {
                            // Only update the actual volume when the user stops dragging
                            audioController.setVolume(uid: device.id, volume: currentVolume)
                        }
                    }
                    .padding(.horizontal, 5)
                }
                .padding(.vertical)
                
                // Set Default Button
                Button(action: {
                    audioController.setDefaultDevice(uid: device.id)
                }) {
                    Text(device.isDefault ? "Current Default" : "Set as Default Output")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(device.isDefault)
                .tint(.blue)
            } else {
                Text("No device selected or loaded.")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(30)
        .frame(minWidth: 450, minHeight: 350)
        // Set up initial volume for the selected device on load
        .onAppear {
            if let device = selectedDevice {
                currentVolume = device.volume
            }
        }
    }
}


// MARK: - Application Entry Point (Required by Xcode)

/// The main application structure that launches the window.
@main
struct AudioControlApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Use standard macos window style
        .windowResizability(.contentSize)
    }
}
