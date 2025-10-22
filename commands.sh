xcode-select --install
clang++ macOS_audio_manager.mm -o audio_manager -std=c++11 -framework CoreAudio -framework CoreFoundation
./audio_manager
####
./audio_manager
--- Available Audio Output Devices ---
[0] Name: MacBook Pro Microphone
    UID: BuiltInMicrophoneDevice
[1] Name: MacBook Pro Speakers
    UID: BuiltInSpeakerDevice
[2] Name: Alain’s iPhone Microphone
    UID: E5002C4D-B680-4E78-924E-6FB600000003
[3] Name: Microsoft Teams Audio
    UID: MSLoopbackDriverDevice_UID
[4] Name: ZoomAudioDevice
    UID: zoom.us.zoomaudiodevice.001
####
./audio_manager BuiltInSpeakerDevice

-----------------
clang++ macOS_audio_manager_V2.mm -o audio_manager -std=c++11 -framework CoreAudio -framework CoreFoundation
codesign --force --sign - audio_manager
codesign --verify --verbose audio_manager