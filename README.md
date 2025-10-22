# README.txt

## macOS Audio Manager Utility

This command-line tool allows you to change the system default audio output device and set its volume.

### How to Use:

1. Open Terminal.
2. Navigate to this folder.
3. Run the tool to see available devices:
   ./audio_manager

4. To set a device as default (using its UID):
   ./audio_manager <DEVICE_UID>

5. To set a device's volume (0-100%):
   ./audio_manager <DEVICE_UID> <VOLUME_PERCENTAGE>

Example (Assuming 51:C2:F6:A3 is a valid UID):
./audio_manager 51:C2:F6:A3 80