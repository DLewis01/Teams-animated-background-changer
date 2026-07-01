# Teams Video Background Swapper

A cross-platform utility for replacing the built-in animated Microsoft Teams video backgrounds with your own MP4 videos.

You can find looping videos with a google search for "animated looping videos" if you don't have any of your own.


The project includes:

- **Windows PowerShell** version
- **macOS Bash** version

The utility automatically locates your Teams background folder, lets you choose which animated background to replace, creates a backup of the original video, optionally validates your replacement video using FFprobe, and regenerates the Teams preview thumbnail using FFmpeg when available.

---

# Features

- Supports Windows 10 and Windows 11
- Supports macOS
- Works with both Teams Classic and the new Microsoft Teams (where applicable)
- Automatically detects Microsoft Teams background folders
- Lists installed animated background slots
- Replace any built-in animated Teams background
- Automatically backs up original videos
- Restore original backgrounds at any time
- Validates replacement videos using FFprobe (if installed)
- Regenerates Teams thumbnails using FFmpeg (if installed)
- Continues to work even when FFmpeg is not installed

### Windows-specific

- Native Windows file picker
- Supports Windows PowerShell 5.1 and PowerShell 7

### macOS-specific

- Optional Homebrew installation of FFmpeg
- Teams installation debugging option

---

# Requirements

## Windows

### Required

- Windows 10 or Windows 11
- Microsoft Teams
- Windows PowerShell 5.1 or PowerShell 7

### Optional

- FFmpeg (recommended)

## macOS

### Required

- macOS
- Bash
- Microsoft Teams

### Optional

- FFmpeg (recommended)

Without FFmpeg:

- Video replacement still works.
- Video validation is disabled.
- Thumbnail generation is disabled.
- Teams may continue displaying the original preview image until it regenerates it automatically.

---

# Installation

## Windows

Download:

```text
Teams-Video-Background-Swapper.ps1
```

Place it anywhere on your computer.

Example:

```text
C:\Scripts\
```

Open PowerShell.

If script execution is blocked:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

Navigate to the script folder:

```powershell
cd C:\Scripts
```

Run:

```powershell
.\Teams-Video-Background-Swapper.ps1
```

---

## macOS

Download:

```text
teams-video-background-swapper.sh
```

Make it executable:

```bash
chmod +x teams-video-background-swapper.sh
```

Run:

```bash
./teams-video-background-swapper.sh
```

or

```bash
bash teams-video-background-swapper.sh
```

---

# Installing FFmpeg

FFmpeg is optional but recommended.

## Windows

Install using Winget:

```powershell
winget install Gyan.FFmpeg
```

or Chocolatey:

```powershell
choco install ffmpeg
```

Or download directly from:

https://ffmpeg.org/download.html

---

## macOS

If Homebrew is not installed:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Verify Homebrew:

```bash
brew --version
```

Install FFmpeg:

```bash
brew install ffmpeg
```

---

## Verify Installation

On either platform:

```text
ffmpeg -version
ffprobe -version
```

If both commands display version information, installation is complete.

---

# Usage

Run the appropriate script.

The main menu is:

```text
Teams Video Background Swapper

1) Replace Background
2) Restore Originals
3) Show Detected Teams Locations
4) Exit
```

On macOS an additional option is available:

```text
Teams Video Background Swapper

1) Replace Background
2) Restore Originals
3) Show Detected Teams Locations
4) Debug Teams Installation
5) Exit
```

---

## Replace Background

Choose **Replace Background**.

The utility will:

1. Display available animated Teams backgrounds.
2. Ask which background to replace.
3. Select your replacement MP4.
   - Windows uses a native file picker.
   - macOS prompts for the file path.
4. Validate the video (if FFprobe is installed).
5. Back up the original background (first replacement only).
6. Replace the Teams video.
7. Generate a new thumbnail (if FFmpeg is installed).

Restart Microsoft Teams if the updated background does not appear immediately.

---

## Restore Originals

Choose **Restore Originals**.

All backed-up videos are restored to their original Teams locations.

---

## Show Detected Teams Locations

Displays all Teams background folders found and identifies the active location.

---

# Backup Locations

## Windows

```text
%LOCALAPPDATA%\TeamsVideoSwapper\Backups
```

## macOS

```text
~/.teams-video-swapper/backups/original/
```

Each original video is backed up only once.

---

# Supported Video Format

Recommended:

- MP4 container
- H.264 video
- AAC audio (optional)
- Landscape orientation
- 16:9 aspect ratio

Other MP4 formats may work, but H.264 provides the best compatibility with Microsoft Teams.

---

# Troubleshooting

## PowerShell scripts are disabled (Windows)

Run in powershell
Set-ExecutionPolicy -Scope Process Bypass


Then run the script again.

---

## Permission denied (macOS)

Make the script executable:


chmod +x teams-video-background-swapper.sh


---

## FFmpeg or FFprobe not found

Install FFmpeg using the instructions above.

Both `ffmpeg` and `ffprobe` are installed together.

Restart your terminal or PowerShell afterwards.

---

## Teams does not show the new thumbnail

Install FFmpeg if it is not already installed.

Run the replacement again.

Restart Microsoft Teams if necessary.

---

## No Teams background folder found

Ensure:

- Microsoft Teams has been launched at least once.
- The built-in animated backgrounds have been downloaded.

macOS users can also use the **Debug Teams Installation** option from the main menu.

---

## Homebrew not found (macOS)

Install Homebrew:

https://brew.sh

---

# Notes

- Original videos are never overwritten without first creating a backup.
- Existing backups are never replaced.
- FFmpeg is optional but recommended.
- Thumbnail generation requires FFmpeg.
- Video validation requires FFprobe.
- The utility continues to function without FFmpeg, although validation and thumbnail generation are unavailable.

---

# Disclaimer

This utility modifies files installed by Microsoft Teams.

Future Teams updates may replace or overwrite custom backgrounds.

Use at your own risk.

---

# License

This project is provided as-is without warranty.
