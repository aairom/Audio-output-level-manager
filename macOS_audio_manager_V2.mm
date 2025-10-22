#include <CoreAudio/CoreAudio.h>
#include <CoreFoundation/CoreFoundation.h>
#include <iostream>
#include <vector>
#include <string>
#include <algorithm>

// --- Utility Functions for Core Audio Error Handling and Property Access ---

// Core Audio functions use OSStatus for error reporting.
#define CHECK_OSSTATUS(status, message) \
    if (status != kAudioHardwareNoError) { \
        std::cerr << "Core Audio Error (" << status << "): " << message << " (Code: " << status << ")" << std::endl; \
        return status; \
    }

// Utility to convert a CFStringRef to a std::string
std::string CFStringRefToString(CFStringRef cfString) {
    if (!cfString) return "";
    CFIndex length = CFStringGetLength(cfString);
    CFIndex maxSize = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8);
    std::vector<char> buffer(maxSize);
    CFStringGetCString(cfString, buffer.data(), maxSize, kCFStringEncodingUTF8);
    return std::string(buffer.data());
}

// Get all output devices
std::vector<AudioDeviceID> getOutputDevices() {
    AudioObjectPropertyAddress address = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    UInt32 dataSize = 0;
    OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &address, 0, NULL, &dataSize);
    if (status != kAudioHardwareNoError || dataSize == 0) {
        return {};
    }

    int numDevices = dataSize / sizeof(AudioDeviceID);
    std::vector<AudioDeviceID> deviceIDs(numDevices);
    
    status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &dataSize, deviceIDs.data());
    if (status != kAudioHardwareNoError) {
        return {};
    }

    // Filter only devices with output streams
    std::vector<AudioDeviceID> outputDeviceIDs;
    for (AudioDeviceID deviceID : deviceIDs) {
        AudioObjectPropertyAddress streamAddress = {
            kAudioDevicePropertyStreamConfiguration,
            kAudioDevicePropertyScopeOutput,
            kAudioObjectPropertyElementMain
        };

        status = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, NULL, &dataSize);
        if (status == kAudioHardwareNoError && dataSize > 0) {
            outputDeviceIDs.push_back(deviceID);
        }
    }

    return outputDeviceIDs;
}

// Get the name of a device
std::string getDeviceName(AudioDeviceID deviceID) {
    AudioObjectPropertyAddress address = {
        kAudioDevicePropertyDeviceNameCFString,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    CFStringRef deviceName = NULL;
    UInt32 dataSize = sizeof(deviceName);
    OSStatus status = AudioObjectGetPropertyData(deviceID, &address, 0, NULL, &dataSize, &deviceName);
    
    if (status == kAudioHardwareNoError && deviceName) {
        std::string name = CFStringRefToString(deviceName);
        // Note: CFStringRef must be released if obtained via CF-function that returns a new object
        // However, Core Audio GetPropertyData often returns a retained CF object when querying CFStringRef properties
        CFRelease(deviceName); 
        return name;
    }
    return "Unknown Device";
}

// Get the UID of a device (useful for persistence)
std::string getDeviceUID(AudioDeviceID deviceID) {
    AudioObjectPropertyAddress address = {
        kAudioDevicePropertyDeviceUID,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    CFStringRef deviceUID = NULL;
    UInt32 dataSize = sizeof(deviceUID);
    OSStatus status = AudioObjectGetPropertyData(deviceID, &address, 0, NULL, &dataSize, &deviceUID);
    
    if (status == kAudioHardwareNoError && deviceUID) {
        std::string uid = CFStringRefToString(deviceUID);
        CFRelease(deviceUID);
        return uid;
    }
    return "";
}

// Find a device ID by its UID
AudioDeviceID getDeviceIDByUID(const std::string& uid) {
    std::vector<AudioDeviceID> devices = getOutputDevices();
    for (AudioDeviceID id : devices) {
        if (getDeviceUID(id) == uid) {
            return id;
        }
    }
    return kAudioObjectUnknown;
}

// Get the system's current default output device ID
AudioDeviceID getCurrentDefaultOutputDeviceID() {
    AudioObjectPropertyAddress address = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    AudioDeviceID currentID = kAudioObjectUnknown;
    UInt32 dataSize = sizeof(AudioDeviceID);
    OSStatus status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &dataSize, &currentID);
    
    if (status != kAudioHardwareNoError) {
        return kAudioObjectUnknown;
    }
    return currentID;
}

// Set the system's default output device
OSStatus setSystemDefaultOutputDevice(AudioDeviceID newDeviceID) {
    AudioObjectPropertyAddress address = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    UInt32 dataSize = sizeof(AudioDeviceID);
    OSStatus status = AudioObjectSetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, dataSize, &newDeviceID);

    CHECK_OSSTATUS(status, "Failed to set default output device.");
    return kAudioHardwareNoError;
}

// Set the master volume (gain) for a device
OSStatus setDeviceVolume(AudioDeviceID deviceID, float volumePercent) {
    // Volume must be between 0.0 and 1.0 (float)
    float targetVolume = std::min(100.0f, std::max(0.0f, volumePercent)) / 100.0f;

    AudioObjectPropertyAddress address = {
        kAudioDevicePropertyVolumeScalar,
        kAudioDevicePropertyScopeOutput, // Always use output scope for volume
        kAudioObjectPropertyElementMain // FIX: Changed from kAudioObjectPropertyElementMaster to kAudioObjectPropertyElementMain
    };

    // Check if volume is controllable
    Boolean isWritable;
    // FIX: Changed from AudioObjectIsPropertyWritable to AudioObjectIsPropertySettable
    OSStatus status = AudioObjectIsPropertySettable(deviceID, &address, &isWritable); 
    if (status != kAudioHardwareNoError || !isWritable) {
        std::cerr << "Error: Volume property for device " << getDeviceName(deviceID) << " is not writable or supported." << std::endl;
        return kAudioObjectUnknown; 
    }

    UInt32 dataSize = sizeof(Float32);
    status = AudioObjectSetPropertyData(deviceID, &address, 0, NULL, dataSize, &targetVolume);
    
    CHECK_OSSTATUS(status, "Failed to set device volume.");
    return kAudioHardwareNoError;
}


int main(int argc, const char * argv[]) {
    // 1. Display Current Default Device
    AudioDeviceID currentDefaultID = getCurrentDefaultOutputDeviceID();
    if (currentDefaultID != kAudioObjectUnknown) {
        std::cout << "-> Current Default Output: " << getDeviceName(currentDefaultID) << " (UID: " << getDeviceUID(currentDefaultID) << ")" << std::endl;
    } else {
        std::cout << "-> Current Default Output: None/Unknown" << std::endl;
    }
    
    // 2. List all available output devices
    std::cout << "\n--- Available Audio Output Devices ---" << std::endl;
    std::vector<AudioDeviceID> devices = getOutputDevices();
    
    if (devices.empty()) {
        std::cout << "No output devices found." << std::endl;
        return 0;
    }

    for (size_t i = 0; i < devices.size(); ++i) {
        std::string name = getDeviceName(devices[i]);
        std::string uid = getDeviceUID(devices[i]);
        std::cout << "[" << i << "] Name: " << name << "\n    UID: " << uid << std::endl;
    }
    std::cout << "--------------------------------------" << std::endl;

    // 3. Command Line Argument Processing
    if (argc > 1) {
        std::string targetUID = argv[1];
        AudioDeviceID targetID = getDeviceIDByUID(targetUID);
        
        if (targetID == kAudioObjectUnknown) {
            std::cerr << "Device with UID '" << targetUID << "' not found." << std::endl;
            return 1;
        }

        // --- A. Set Default Device ---
        if (targetID != currentDefaultID) {
            std::cout << "Attempting to set default output device to: " << getDeviceName(targetID) << std::endl;
            OSStatus status = setSystemDefaultOutputDevice(targetID);
            
            if (status == kAudioHardwareNoError) {
                std::cout << "Successfully changed system default output." << std::endl;
            } else {
                return 1;
            }
        } else {
             std::cout << "Device is already the system default output." << std::endl;
        }


        // --- B. Set Volume if Third Argument is Provided ---
        if (argc > 2) {
            try {
                // Parse the volume percentage from argument 2
                float volumePercent = std::stof(argv[2]); 
                std::cout << "Attempting to set volume to " << volumePercent << "%..." << std::endl;
                
                OSStatus volumeStatus = setDeviceVolume(targetID, volumePercent);

                if (volumeStatus == kAudioHardwareNoError) {
                    std::cout << "Successfully set volume for " << getDeviceName(targetID) << " to " << volumePercent << "%." << std::endl;
                }
            } catch (const std::exception& e) {
                std::cerr << "Error: Invalid volume percentage argument provided." << std::endl;
                return 1;
            }
        }
    } else {
        std::cout << "\nTo manage devices, run this program with arguments:" << std::endl;
        std::cout << "1. Set Default Output: ./audio_manager <DEVICE_UID>" << std::endl;
        std::cout << "2. Set Volume (0-100%): ./audio_manager <DEVICE_UID> <VOLUME_PERCENTAGE>" << std::endl;
    }
    
    return 0;
}
