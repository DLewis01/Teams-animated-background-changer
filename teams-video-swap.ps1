###############################################################################
# Teams Video Background Swapper for Windows
#
# Replaces built-in Microsoft Teams animated backgrounds with your own MP4s.
# Automatically backs up originals and optionally regenerates thumbnails.
#
# Works with:
#   • Windows PowerShell 5.1
#   • PowerShell 7+
###############################################################################

Add-Type -AssemblyName System.Windows.Forms

###############################################################################
# Configuration
###############################################################################

$AppDir = Join-Path $env:LOCALAPPDATA "TeamsVideoSwapper"
$BackupDir = Join-Path $AppDir "Backups"

New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

###############################################################################
# FFmpeg Detection
###############################################################################

$Global:FFmpegAvailable = $false
$Global:FFprobeAvailable = $false

if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
    $Global:FFmpegAvailable = $true
}

if (Get-Command ffprobe -ErrorAction SilentlyContinue) {
    $Global:FFprobeAvailable = $true
}

###############################################################################
# Teams Folder Discovery
###############################################################################

function Get-TeamsFolders {

    $folders = @()

    $possible = @(
        "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds",
        "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads",
        "$env:APPDATA\Microsoft\Teams\Backgrounds",
        "$env:APPDATA\Microsoft\Teams\Backgrounds\Uploads",
        "$env:LOCALAPPDATA\Microsoft\Teams\Backgrounds",
        "$env:LOCALAPPDATA\Microsoft\Teams\Backgrounds\Uploads"
    )

    foreach ($folder in $possible)
    {
        if (Test-Path $folder)
        {
            if (Get-ChildItem $folder -Filter *.mp4 -ErrorAction SilentlyContinue)
            {
                $folders += $folder
            }
        }
    }

    return $folders | Sort-Object -Unique

}



###############################################################################
# Choose Best Folder
###############################################################################

function Select-BestFolder {

    param(
        [string[]]$Folders
    )

    $bestScore = -1
    $bestFolder = $null

    foreach ($folder in $Folders)
    {
        $mp4Count = @(Get-ChildItem $folder -Filter *.mp4 -ErrorAction SilentlyContinue).Count

        $thumbCount = @(
            Get-ChildItem $folder -Include *.png,*.jpg,*.jpeg,*.webp -File -ErrorAction SilentlyContinue
        ).Count

        $score = ($mp4Count * 100) + ($thumbCount * 20)

        if ($folder -match "MSTeams") {
            $score += 5
        }

        if ($folder -match "Packages") {
            $score += 5
        }

        if ($score -gt $bestScore)
        {
            $bestScore = $score
            $bestFolder = $folder
        }
    }

    return $bestFolder

}

###############################################################################
# List Slots
###############################################################################

function Get-BackgroundSlots {

    param(
        [string]$Folder
    )

    $Global:Slots = Get-ChildItem `
        $Folder `
        -Filter *.mp4 |
        Sort-Object Name

    Write-Host
    Write-Host "Available Teams Background Slots"
    Write-Host "================================"
    Write-Host

    $i = 1

    foreach ($slot in $Global:Slots)
    {
        Write-Host "$i) $($slot.Name)"
        $i++
    }

    Write-Host

}

###############################################################################
# Select Slot
###############################################################################

function Select-Slot {

    do {

        $choice = Read-Host "Select slot"

    } until ($choice -match '^\d+$')

    $index = [int]$choice - 1

    if ($index -lt 0 -or $index -ge $Global:Slots.Count)
    {
        throw "Invalid slot selected."
    }

    return $Global:Slots[$index]

}

###############################################################################
# Select Replacement Video
###############################################################################

function Select-Video {

    $dialog = New-Object System.Windows.Forms.OpenFileDialog

    $dialog.Title = "Choose replacement video"

    $dialog.Filter = "MP4 files (*.mp4)|*.mp4"

    if ($dialog.ShowDialog() -ne "OK")
    {
        return $null
    }

    return $dialog.FileName

}

###############################################################################
# Backup Original
###############################################################################

function Backup-Original {

    param(
        [System.IO.FileInfo]$Target
    )

    $backup = Join-Path $BackupDir $Target.Name

    if (-not (Test-Path $backup))
    {
        Write-Host
        Write-Host "Backing up original..."

        Copy-Item `
            $Target.FullName `
            $backup

        Write-Host "Saved:"
        Write-Host $backup
    }
    else
    {
        Write-Host
        Write-Host "Original already backed up."
    }

}

###############################################################################
# Replace Video
###############################################################################

function Replace-Video {

    param(
        [string]$Source,
        [System.IO.FileInfo]$Target
    )

    Write-Host
    Write-Host "Installing custom video..."

    if ($Global:FFprobeAvailable)
    {
        & ffprobe `
            -v error `
            "$Source" *> $null

        if ($LASTEXITCODE -ne 0)
        {
            Write-Host
            Write-Host "The selected file is not a valid MP4."
            return $false
        }
    }

    Copy-Item `
        $Source `
        $Target.FullName `
        -Force

    Write-Host
    Write-Host "Done."
    Write-Host
    Write-Host "Replaced:"
    Write-Host $Target.Name

    return $true

}

###############################################################################
# Generate Thumbnail
###############################################################################

function Generate-Thumbnail {

    param(
        [System.IO.FileInfo]$Target
    )

    if (-not $Global:FFmpegAvailable)
    {
        Write-Host
        Write-Host "WARNING:"
        Write-Host
        Write-Host "FFmpeg is not installed."
        Write-Host
        Write-Host "The replacement video will work,"
        Write-Host "but the Teams thumbnail may remain"
        Write-Host "the original image."
        Write-Host
        return
    }

    $thumb = $null

    foreach ($ext in @("png","jpg","jpeg","webp"))
    {
        $candidate = [System.IO.Path]::ChangeExtension(
            $Target.FullName,
            $ext
        )

        if (Test-Path $candidate)
        {
            $thumb = $candidate
            break
        }
    }

    if (-not $thumb)
    {
        $thumb = [System.IO.Path]::ChangeExtension(
            $Target.FullName,
            "png"
        )
    }

    Write-Host
    Write-Host "Generating thumbnail..."

    $duration = & ffprobe `
        -v error `
        -show_entries format=duration `
        -of default=noprint_wrappers=1:nokey=1 `
        "$($Target.FullName)"

    if (-not $duration)
    {
        $time = 1
    }
    else
    {
        $time = [double]$duration * 0.2
    }

    & ffmpeg `
        -y `
        -ss $time `
        -i "$($Target.FullName)" `
        -frames:v 1 `
        -q:v 2 `
        -vf "scale=320:-1" `
        "$thumb" *> $null

    if (Test-Path $thumb)
    {
        Write-Host "Thumbnail updated."
    }
    else
    {
        Write-Host "Unable to generate thumbnail."
    }

}

###############################################################################
# Restore Originals
###############################################################################

function Restore-Originals {

    Write-Host
    $answer = Read-Host "Restore all original Teams backgrounds? [y/N]"

    if ($answer -notmatch "^[Yy]$")
    {
        Write-Host
        Write-Host "Restore cancelled."
        return
    }

    Write-Host
    Write-Host "Restoring..."

    $count = 0

    Get-ChildItem $BackupDir -File | ForEach-Object {

        Copy-Item `
            $_.FullName `
            (Join-Path $Global:TeamsFolder $_.Name) `
            -Force

        $count++

    }

    Write-Host
    Write-Host "Restore complete."
    Write-Host "Files restored: $count"

}

###############################################################################
# Startup
###############################################################################

$folders = Get-TeamsFolders

if ($folders.Count -eq 0)
{
    Write-Host
    Write-Host "No Teams Backgrounds folder found."
    Pause
    exit
}

$Global:TeamsFolder = Select-BestFolder $folders

###############################################################################
# Main Menu
###############################################################################

while ($true)
{

    Clear-Host

    Write-Host "Teams Video Background Swapper"
    Write-Host "============================="
    Write-Host
    Write-Host "Using:"
    Write-Host $Global:TeamsFolder
    Write-Host

    if ($Global:FFmpegAvailable)
    {
        Write-Host "FFmpeg: Installed"
    }
    else
    {
        Write-Host "FFmpeg: Not Installed"
        Write-Host "Video replacement will work, but thumbnails may be incorrect."
    }

    Write-Host
    Write-Host "1) Replace Background"
    Write-Host "2) Restore Originals"
    Write-Host "3) Show Detected Teams Locations"
    Write-Host "4) Exit"
    Write-Host

    $choice = Read-Host "Choose"

    switch ($choice)
    {

        "1"
        {
            Get-BackgroundSlots $Global:TeamsFolder

            try
            {
                $target = Select-Slot
            }
            catch
            {
                Write-Host
                Write-Host $_.Exception.Message
                Pause
                continue
            }

            $source = Select-Video

            if (-not $source)
            {
                continue
            }

            Backup-Original $target

            if (Replace-Video $source $target)
            {
                Generate-Thumbnail $target
            }

            Write-Host
            Pause
        }

        "2"
        {
            Restore-Originals
            Pause
        }

        "3"
        {
            Write-Host
            Write-Host "Detected Teams Background Locations"
            Write-Host "=================================="
            Write-Host

            foreach ($folder in $folders)
            {
                if ($folder -eq $Global:TeamsFolder)
                {
                    Write-Host "* $folder (selected)"
                }
                else
                {
                    Write-Host "  $folder"
                }
            }

            Write-Host
            Pause
        }

        "4"
        {
            break
        }

        default
        {
            Write-Host
            Write-Host "Invalid selection."
            Start-Sleep -Seconds 1
        }

    }

}

Write-Host
Write-Host "Goodbye."
