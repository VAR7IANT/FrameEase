<#
.SYNOPSIS
  Reports the Windows display modes and (optionally) switches the primary display to a larger one.

.DESCRIPTION
  GitHub's windows-2022 runner starts on a small virtual display. Windows refuses to make a top-level window bigger
  than the desktop, so a window that asks for 1600x900 silently becomes smaller and any screenshot of it is NOT a
  1600x900 capture. This script lists the modes the display driver offers, tries to switch to the requested one, and
  prints the result either way, so the CI log shows what the smoke test actually ran on.

  It never fails the job: the smoke test measures the real window size itself and refuses to label a capture with a
  size it did not get.
#>
param(
    [int]$Width = 0,
    [int]$Height = 0
)

Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class FeDisplay {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public short dmSpecVersion; public short dmDriverVersion; public short dmSize; public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX; public int dmPositionY; public int dmDisplayOrientation; public int dmDisplayFixedOutput;
        public short dmColor; public short dmDuplex; public short dmYResolution; public short dmTTOption; public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel; public int dmPelsWidth; public int dmPelsHeight; public int dmDisplayFlags; public int dmDisplayFrequency;
        public int dmICMMethod; public int dmICMIntent; public int dmMediaType; public int dmDitherType;
        public int dmReserved1; public int dmReserved2; public int dmPanningWidth; public int dmPanningHeight;
    }
    [DllImport("user32.dll", CharSet = CharSet.Ansi)] public static extern bool EnumDisplaySettings(string device, int mode, ref DEVMODE dm);
    [DllImport("user32.dll", CharSet = CharSet.Ansi)] public static extern int ChangeDisplaySettings(ref DEVMODE dm, int flags);

    public static DEVMODE Blank() { var d = new DEVMODE(); d.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE)); return d; }
}
"@
Add-Type -AssemblyName System.Windows.Forms

function Show-State([string]$label) {
    $dm = [FeDisplay]::Blank()
    [void][FeDisplay]::EnumDisplaySettings($null, -1, [ref]$dm)
    $s = [System.Windows.Forms.Screen]::PrimaryScreen
    Write-Host ("{0}: mode {1}x{2} @{3} Hz {4} bpp | bounds {5}x{6} | working area {7}x{8}" -f $label,
        $dm.dmPelsWidth, $dm.dmPelsHeight, $dm.dmDisplayFrequency, $dm.dmBitsPerPel,
        $s.Bounds.Width, $s.Bounds.Height, $s.WorkingArea.Width, $s.WorkingArea.Height)
}

Show-State "display before"

$modes = New-Object System.Collections.Generic.SortedSet[string]
$i = 0
$dm = [FeDisplay]::Blank()
while ([FeDisplay]::EnumDisplaySettings($null, $i, [ref]$dm)) {
    [void]$modes.Add(("{0}x{1}" -f $dm.dmPelsWidth, $dm.dmPelsHeight))
    $i++
    $dm = [FeDisplay]::Blank()
}
Write-Host ("driver offers {0} mode entries, {1} distinct sizes: {2}" -f $i, $modes.Count, ($modes -join "  "))

if ($Width -gt 0 -and $Height -gt 0) {
    $want = [FeDisplay]::Blank()
    [void][FeDisplay]::EnumDisplaySettings($null, -1, [ref]$want)
    $want.dmPelsWidth = $Width
    $want.dmPelsHeight = $Height
    $want.dmFields = 0x80000 -bor 0x100000      # DM_PELSWIDTH | DM_PELSHEIGHT
    $rc = [FeDisplay]::ChangeDisplaySettings([ref]$want, 0)
    $names = @{ 0 = "DISP_CHANGE_SUCCESSFUL"; 1 = "DISP_CHANGE_RESTART"; -1 = "DISP_CHANGE_FAILED"; -2 = "DISP_CHANGE_BADMODE"; -3 = "DISP_CHANGE_NOTUPDATED"; -4 = "DISP_CHANGE_BADFLAGS"; -5 = "DISP_CHANGE_BADPARAM" }
    Write-Host ("ChangeDisplaySettings {0}x{1} -> {2} ({3})" -f $Width, $Height, $rc, $names[[int]$rc])
    Start-Sleep -Seconds 2
    Show-State "display after"
}
exit 0
