

# RustDesk Multi-Instance Manager (Improved)

A Windows PowerShell GUI tool to manage multiple **RustDesk profiles (instances)** with reliable profile switching and configuration persistence.


<img width="542" height="624" alt="Pasted image 20260502101319" src="https://github.com/user-attachments/assets/bdb2ab2d-77d6-459d-bb2e-33d0f9d43d7b" />


This fork fixes major issues in the original project and introduces a safer, predictable way to handle multiple RustDesk configurations.

---

## ✨ What’s new in this fork

- ✅ **Reliable profile switching**
  - Uses a **profile copy/switch method** instead of unstable environment variable tricks
  - Ensures RustDesk always loads the correct configuration (sessions, favorites, IDs)

- ✅ **No more broken configs**
  - Removed junctions and `%LOCALAPPDATA%` overrides that caused data loss or empty sessions

- ✅ **Config persistence**
  - Remembers:
    - `RustDesk.exe` path
    - Instance directory  
  - Stored in:
    ```
    %APPDATA%\RustDeskMultiInstanceTool\config.json
    ```

- ✅ **Active instance tracking**
  - Tracks which instance is currently active
  - Automatically saves the current profile before switching

- ✅ **Safe default profile backup**
  - First run creates a backup of your original:
    ```
    %APPDATA%\RustDesk
    ```
  - Can be restored at any time

- ✅ **GUI improvements**
  - Config window with browse buttons
  - Instance list with active indicator
  - Cleaner and more predictable behavior

---

## ⚙️ How it works

This tool does **profile switching (not parallel multi-instance)**:

1. Select an instance  
2. The tool:
   - Stops RustDesk  
   - Saves the current profile to its instance folder  
   - Copies the selected instance into:
     ```
     %APPDATA%\RustDesk
     ```
3. Launches RustDesk normally  

✔ Result: RustDesk behaves exactly like a normal install, but with different profiles.

---

## 📁 Instance structure

instances/  
├── instance1/  
│ └── RustDesk/  
├── instance2/  
│ └── RustDesk/


---

## 🚀 Usage

1. Open **Config**
   - Select `RustDesk.exe`
   - Choose an **instance directory**

2. Create instances
   - Click **Create Instance**
   - Each instance gets its own RustDesk config

3. Switch & start
   - Select an instance
   - Click **Switch & Start**

---

## ⚠️ Important Notes

- Only **one instance runs at a time**
- This tool **does not support true simultaneous sessions**
- RustDesk must be **closed before switching** (currently being enforced in the app/code)
- Do **not enable RustDesk service mode** (uninstall Rustdesk.MSI and use the .EXE executable instead)

---

## 🔧 Why this fork?

The original implementation relied on:
- `%APPDATA%` overrides ❌


These caused:
- Missing sessions/favorites  
- Broken configs  
- Inconsistent behavior  

