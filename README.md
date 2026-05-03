# RustDesk Multi-Instance Manager v10

A Windows PowerShell 5.x GUI tool to manage multiple **RustDesk instances**, with optional **Tailscale account switching** so each RustDesk instance can be paired with the correct Tailscale account/network.


&nbsp;
<div align="center">
  <img width="600" height="600" alt="screenshot png" src="https://github.com/user-attachments/assets/6c261389-3b56-41a0-a9ff-e0efcafe7756" />
</div>
&nbsp;

This fork builds on the original RustDesk multi-instance script by suuhm changing the profile switching method, adding persistent configuration, an improved UI, and optional Tailscale integration.

---
&nbsp;

1. **Clone the Repository**  
   ```bash
   git clone https://github.com/gugatec/rustdesk-multi-instance.git
   cd rustdesk-multi-instance
   ```

2. **Run the Script**  
   Open PowerShell (5.x) as Administrator and execute the script:  
   ```powershell
   powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\rustdesk-multi-instance.ps1
   ```

&nbsp;

---


## ✨ What’s new in this fork

### ✅ Reliable RustDesk profile switching

- Uses a profile copy/switch method instead of relying on environment-variable overrides.
- Ensures RustDesk loads the correct configuration for each instance, including sessions, favorites, IDs, and other profile data.
- Stops RustDesk before switching profiles.
- Saves the current active profile back into its instance folder before loading another instance.

### ✅ Optional Tailscale account switching

- Tailscale support can be enabled or disabled from the GUI.
- Users who only want RustDesk profile switching can disable Tailscale functionality completely.
- When enabled, the tool can list available Tailscale accounts/profiles using the Tailscale CLI.
- Each RustDesk instance can be associated with a Tailscale account/profile.
- When clicking **Switch && Start**, the tool switches to the associated Tailscale account before launching RustDesk.
- Tailscale dropdown displays the account email plus the four-character profile ID, for example:

```text
user@example.com (5ff9)
```

### ✅ Config persistence

The tool remembers:

- `RustDesk.exe` path
- RustDesk instance directory
- Optional `tailscale.exe` path
- Whether Tailscale functionality is enabled
- RustDesk instance to Tailscale account/profile associations

Configuration is stored in:

```text
%APPDATA%\RustDeskMultiInstanceTool\config.json
```

### ✅ Active instance tracking

- Tracks which RustDesk instance is currently active.
- Marks the active instance in the GUI.
- Automatically saves the current profile before switching to another one.
- Clears the active marker when an active instance is removed.

### ✅ Safe default profile backup

On first run, the tool creates a backup of the original RustDesk profile from:

```text
%APPDATA%\RustDesk
```

The backup is stored under the tool configuration folder and can be restored through the GUI.

### ✅ Improved GUI / UIX

- Menu bar with:
  - **File > Config**
  - **File > Exit**
  - **Help > Help**
  - **Help > About**
- Segmented layout:
  - **RUSTDESK INSTANCES**
  - **TAILSCALE ACCOUNTS**
- Scrollable instance table using a static header row.
- Instance table columns:
  - **RUSTDESK INSTANCES**
  - **TAILSCALE ACCOUNT**
- Six main RustDesk action buttons:
  - **Switch && Start**
  - **Refresh List**
  - **Create Instance**
  - **Restore Default Profile**
  - **Open Tool Config Folder**
  - **Remove Instance**
- Remove Instance includes a written Yes/No confirmation before deleting the selected instance folder.
- About window shows the current version and GitHub link.
- Help window provides concise setup and usage instructions.

---

## ⚙️ How it works

This tool performs **profile switching**, not true parallel multi-instance execution.

### RustDesk switching flow

1. Select a RustDesk instance.
2. Click **Switch && Start**.
3. The tool:
   - Stops any running RustDesk process.
   - Saves the currently active real RustDesk profile back to its instance folder.
   - Copies the selected instance profile into:

```text
%APPDATA%\RustDesk
```

4. RustDesk launches normally using the selected profile.

Result: RustDesk behaves like a normal install, but with different saved profiles depending on the selected instance.

### Tailscale switching flow, when enabled

1. Enable Tailscale functionality.
2. Configure or auto-detect `tailscale.exe`.
3. Refresh the Tailscale account list.
4. Select a RustDesk instance.
5. Select a Tailscale account/profile from the dropdown.
6. Click **Associate Tailscale**.
7. When clicking **Switch && Start**, the tool:
   - switches the RustDesk profile,
   - switches Tailscale to the associated account/profile,
   - launches RustDesk.

If Tailscale is disabled, no Tailscale command is called and the app works as a RustDesk-only profile switcher.

---

## 📁 Instance structure

Example instance directory:

```text
instances/
├── instance1/
│   └── RustDesk/
├── instance2/
│   └── RustDesk/
└── client-lab/
    └── RustDesk/
```

Each instance folder stores its own RustDesk profile data under its own `RustDesk` subfolder.

---

## 🚀 Usage

### 1. Open Config

Use **File > Config**.

Configure:

- `RustDesk.exe` path
- RustDesk instance directory
- Optional `tailscale.exe` path
- Whether Tailscale switching is enabled

### 2. Create RustDesk instances

1. Click **Create Instance**.
2. Enter an instance name.
3. The tool creates a new instance folder and copies the current RustDesk profile into it.

### 3. Associate Tailscale accounts, optional

1. Enable Tailscale functionality.
2. Click **Refresh Tailscale**.
3. Select a RustDesk instance in the table.
4. Select a Tailscale account/profile in the dropdown.
5. Click **Associate Tailscale**.

The instance table will show the Tailscale account associated with each RustDesk instance.

### 4. Switch and start

1. Select a RustDesk instance.
2. Click **Switch && Start**.
3. The tool switches the RustDesk profile.
4. If Tailscale is enabled and the instance has an association, the tool switches Tailscale too.
5. RustDesk launches.

### 5. Remove an instance

1. Select the instance.
2. Click **Remove Instance**.
3. Confirm the deletion in the Yes/No prompt.

This deletes the selected instance folder and removes its saved Tailscale association.

### 6. Restore the original/default profile

Click **Restore Default Profile** to restore the original RustDesk profile backup created by the tool.

---

## 🧩 Tailscale notes

Tailscale integration depends on the Tailscale CLI.

The tool uses commands equivalent to:

```powershell
tailscale switch --list
tailscale switch <profile-id-or-account>
```

The script stores the usable Tailscale switch key internally and displays a friendlier account label in the GUI.

For users who do not use Tailscale:

- leave Tailscale disabled,
- do not configure `tailscale.exe`,
- use the tool normally as a RustDesk-only manager.

---

## ⚠️ Important notes

- Only one RustDesk profile is active at a time.
- This tool does not provide simultaneous RustDesk sessions.
- RustDesk is forcibly closed before switching profiles.
- Use the standalone RustDesk `.exe` version.
- Do not use RustDesk service mode for this workflow.
- If you installed RustDesk through the MSI/service installer, uninstall it and use the `.exe` executable instead.
- Tailscale functionality is optional and should be enabled only when needed.

---

## ❓ Why this fork?

The original implementation relied on `%APPDATA%` environment-variable overrides, which do not work reliably with current RustDesk behavior.

This caused issues such as:

- missing sessions and favorites,
- broken or inconsistent configs,
- paths not being remembered,
- unreliable switching behavior.

This fork uses an explicit copy/switch workflow so the real RustDesk profile directory always contains the selected instance before RustDesk launches.

---

## Credits
- Original script by suuhm: <https://github.com/suuhm/rustdesk-multi-instance>
