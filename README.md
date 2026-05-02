RustDesk Multi-Instance Manager (Improved)

A Windows PowerShell GUI tool to manage multiple RustDesk profiles (instances) with reliable profile switching and configuration persistence.

This fork fixes major issues in the original project and introduces a safer, predictable way to handle multiple RustDesk configurations.

✨ What’s new in this fork
✅ Reliable profile switching
Uses a profile copy/switch method instead of unstable environment variable tricks
Ensures RustDesk always loads the correct configuration (sessions, favorites, IDs)
✅ No more broken configs
Removed junctions and %LOCALAPPDATA% overrides that caused data loss or empty sessions
✅ Config persistence
Remembers:
RustDesk.exe path
Instance directory

Stored in:

%APPDATA%\RustDeskMultiInstanceTool\config.json
✅ Active instance tracking
Tracks which instance is currently active
Automatically saves the current profile before switching
✅ Safe default profile backup

First run creates a backup of your original:

%APPDATA%\RustDesk
Can be restored at any time
✅ GUI improvements
Config window with browse buttons
Instance list with active indicator
Cleaner and more predictable behavior
⚙️ How it works

This tool does profile switching (not parallel multi-instance):

Select an instance
The tool:
Stops RustDesk
Saves the current profile to its instance folder

Copies the selected instance into:

%APPDATA%\RustDesk
Launches RustDesk normally

✔ Result: RustDesk behaves exactly like a normal install, but with different profiles.

📁 Instance structure
instances/
 ├── instance1/
 │    └── RustDesk/
 ├── instance2/
 │    └── RustDesk/
🚀 Usage
Open Config
Select RustDesk.exe
Choose an instance directory
Create instances
Click Create Instance
Each instance gets its own RustDesk config
Switch & start
Select an instance
Click Switch & Start
⚠️ Important Notes
Only one instance runs at a time
This tool does not support true simultaneous sessions
RustDesk must be closed before switching
Do not enable RustDesk service mode
🔧 Why this fork?

The original implementation relied on:

%APPDATA% overrides ❌
%LOCALAPPDATA% hacks ❌
Junction links ❌

These caused:

Missing sessions/favorites
Broken configs
Inconsistent behavior

This fork replaces all of that with a simple, robust approach that matches how RustDesk actually works on Windows.

📌 Future ideas
Portable mode support
True multi-instance via separate binaries
Instance cloning/duplication UI
Export/import profiles
