<#
.SYNOPSIS
    Parse and realize every theme XAML file against real WPF, in a Playnite-shaped context.

.DESCRIPTION
    tools/validate_theme.py proves the files are well-formed XML and that their resource
    keys resolve. Hard rule 10 warns that this is necessary but not sufficient: Playnite
    loads theme files through Xaml.FromFile -> XamlReader.Load, which also throws on an
    unknown property, a bad type converter, or a StaticResource that cannot be found. The
    first throw sets allLoaded = false, breaks the loop, and drops the user all the way
    back to Playnite's default theme - silently, with two lines in playnite.log.

    This script is the check that catches that class. It cannot run in CI, because it needs
    Windows and a Playnite install; run it before opening a PR that touches XAML.

    Four things have to be true or the run measures the harness instead of the theme:

    1. 32-BIT POWERSHELL. Playnite.DesktopApp.exe is PE32/x86, so a 64-bit host cannot load
       its assemblies and every Views/*.xaml fails with "Failed to create a 'Type' from the
       text 'TopPanel'". This single detail is the difference between 28 and 78 passing
       files. The script re-launches itself under SysWOW64 automatically.
    2. PLAYNITE'S ASSEMBLIES. Its CLR types (TopPanel, Sidebar, WindowBase, GameListItem)
       are referenced by clr-namespace from the theme's Views.
    3. AN APPLICATION OBJECT. StaticResource falls back to Application.Current.Resources,
       which is how one theme file resolves a key another file defines. Playnite's default
       theme, Localization and Templates are merged into it first, then the theme's own
       files as they parse - mirroring what ApplyTheme ends up with.
    4. FORCED REALIZATION. ResourceDictionary defers its values, so a broken StaticResource
       stays invisible until something reads the key. Every value is read explicitly.

    EXPECTED FAILURE: Media.xaml always fails on a BitmapImage. {ThemeFile} resolves against
    a deployed theme directory, which source/ is not (hard rule 7). Treat any OTHER failure
    as real. A clean run is therefore "1 failed", not "0 failed".

.PARAMETER Source
    The theme source directory. Defaults to source/ next to this script's repo root.

.PARAMETER Playnite
    Playnite install root. Defaults to F:\Playnite.

.EXAMPLE
    pwsh -File tools/check_xaml_wpf.ps1
    powershell.exe -File tools/check_xaml_wpf.ps1 -Playnite "D:\Playnite"
#>
[CmdletBinding()]
param(
    [string] $Source,
    [string] $Playnite = 'F:\Playnite'
)

$ErrorActionPreference = 'Stop'

if (-not $Source) {
    $Source = Join-Path (Split-Path -Parent $PSScriptRoot) 'source'
}

# --- 1. re-launch under 32-bit PowerShell if needed -------------------------------------
# pwsh 7 has no GDI System.Drawing and, more importantly, a 64-bit host cannot load
# Playnite's x86 assemblies. Bail out to SysWOW64 Windows PowerShell and run there.
if ([Environment]::Is64BitProcess) {
    $wow = Join-Path $env:WINDIR 'SysWOW64\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path $wow)) {
        Write-Host "FAIL  need 32-bit PowerShell at $wow (Playnite is x86)"
        exit 2
    }
    Write-Host "relaunching under 32-bit PowerShell (Playnite is x86)..."
    & $wow -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -Source $Source -Playnite $Playnite
    exit $LASTEXITCODE
}

if (-not (Test-Path $Source))   { Write-Host "FAIL  no source directory: $Source";   exit 2 }
if (-not (Test-Path $Playnite)) { Write-Host "FAIL  no Playnite install: $Playnite"; exit 2 }

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

# --- 2. make Playnite's own types loadable ----------------------------------------------
$script:PlayniteDir = $Playnite
[AppDomain]::CurrentDomain.add_AssemblyResolve({
    param($sender, $e)
    $name = (New-Object Reflection.AssemblyName $e.Name).Name
    $path = Join-Path $script:PlayniteDir "$name.dll"
    if (Test-Path $path) { [Reflection.Assembly]::LoadFrom($path) } else { $null }
})
foreach ($name in 'Playnite', 'Playnite.SDK') {
    $path = Join-Path $Playnite "$name.dll"
    if (Test-Path $path) { [void][Reflection.Assembly]::LoadFrom($path) }
}
$exe = Join-Path $Playnite 'Playnite.DesktopApp.exe'
if (Test-Path $exe) { [void][Reflection.Assembly]::LoadFrom($exe) }

# --- 3. build the resource context ------------------------------------------------------
if (-not [Windows.Application]::Current) { $null = New-Object Windows.Application }
$app = [Windows.Application]::Current

# Constants -> Common -> Media first, mirroring App.xaml's merge order; everything else after.
function Get-OrderedXaml([string] $dir, [switch] $SkipLocalization) {
    $lead = 'Constants.xaml', 'Common.xaml', 'Media.xaml'
    $files = @()
    foreach ($name in $lead) {
        $path = Join-Path $dir $name
        if (Test-Path $path) { $files += Get-Item $path }
    }
    $rest = Get-ChildItem $dir -Recurse -Filter *.xaml | Where-Object { $_.Name -notin $lead }
    if ($SkipLocalization) { $rest = $rest | Where-Object { $_.FullName -notlike '*\Localization\*' } }
    $files + $rest
}

function Merge-Dir([string] $dir) {
    if (-not (Test-Path $dir)) { return 0 }
    $merged = 0
    foreach ($file in Get-OrderedXaml $dir) {
        try {
            $stream = [IO.File]::OpenRead($file.FullName)
            try { $dict = [Windows.Markup.XamlReader]::Load($stream) } finally { $stream.Dispose() }
            if ($dict -is [Windows.ResourceDictionary]) {
                $app.Resources.MergedDictionaries.Add($dict); $merged++
            }
        } catch { }   # a default-theme file we cannot parse is not this theme's problem
    }
    $merged
}

$context  = Merge-Dir (Join-Path $Playnite 'Templates\Themes')
$context += Merge-Dir (Join-Path $Playnite 'Localization')
$context += Merge-Dir (Join-Path $Playnite 'Themes\Desktop\Default')
Write-Host "context: merged $context dictionaries from Playnite"
if ($context -lt 40) {
    Write-Host "FAIL  Playnite context barely merged - results would be meaningless. Check -Playnite."
    exit 2
}

# --- 4. parse and realize the theme -----------------------------------------------------
$files = @(Get-OrderedXaml $Source -SkipLocalization)
$loc = Join-Path $Source 'Localization'
if (Test-Path $loc) { $files += Get-ChildItem $loc -Filter *.xaml }

$expected = 'Media.xaml'   # {ThemeFile} cannot resolve outside a deployed theme dir
$pass = 0; $unexpected = 0; $known = 0
foreach ($file in $files) {
    $rel = $file.FullName.Substring($Source.Length + 1)
    try {
        $stream = [IO.File]::OpenRead($file.FullName)
        try { $dict = [Windows.Markup.XamlReader]::Load($stream) } finally { $stream.Dispose() }
        if ($dict -is [Windows.ResourceDictionary]) {
            foreach ($key in @($dict.Keys)) { $null = $dict[$key] }   # force deferred values
            $app.Resources.MergedDictionaries.Add($dict)
        }
        $pass++
    } catch {
        $message = $_.Exception.Message -replace "`r?`n", ' '
        if ($message.Length -gt 260) { $message = $message.Substring(0, 260) + '...' }
        if ($file.Name -eq $expected) {
            $known++
            Write-Host "known $rel (hard rule 7: {ThemeFile} needs a deployed theme dir)"
        } else {
            $unexpected++
            Write-Host "FAIL  $rel"
            Write-Host "      $message"
        }
    }
}

Write-Host ''
Write-Host "parsed and realized: $pass    expected failures: $known    unexpected: $unexpected"
if ($unexpected -gt 0) { exit 1 }
Write-Host 'ok    every theme file parses and realizes against real WPF'
exit 0
