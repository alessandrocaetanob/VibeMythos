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

    It runs TWO phases, because Playnite does two different things and only one of them was
    modelled before 2026-08-20 - which is how a theme-killing bug shipped past a green run.

    PHASE 1, pre-flight. ThemeManager.ApplyTheme parses EVERY theme file through Xaml.FromFile
    BEFORE it merges ANY of them. So during that pass a StaticResource resolves against
    Playnite's default theme only: the theme's own Constants.xaml has been parsed but is not
    yet in scope. Phase 1 reproduces that exactly - Playnite's dictionaries merged, zero theme
    dictionaries - and it is the phase that matters, because one failure here costs the user
    the entire theme.

    The trap it exists to catch: a Storyboard inside a Style or ControlTemplate must be frozen
    for the timing system, and freezing forces its StaticResource to resolve eagerly, right
    there in pre-flight, instead of being deferred the way an ordinary Setter value is. So a
    Duration or easing key in Constants.xaml is unreachable from a storyboard - DynamicResource
    cannot freeze, and StaticResource resolves too early. Define those locally in the file.

    PHASE 2, runtime. Merge as you go and force every dictionary value to realize, which is
    roughly the state after ApplyTheme succeeds. This catches deferred breakage that pre-flight
    legitimately does not see, since a normal Setter's StaticResource is resolved late.

    Three things have to be true or the run measures the harness instead of the theme:

    1. 32-BIT POWERSHELL. Playnite.DesktopApp.exe is PE32/x86, so a 64-bit host cannot load
       its assemblies and every Views/*.xaml fails with "Failed to create a 'Type' from the
       text 'TopPanel'". This single detail is the difference between 28 and 78 passing files.
       The script re-launches itself under SysWOW64 automatically.
    2. PLAYNITE'S ASSEMBLIES, for the CLR types the theme's Views reference by clr-namespace.
    3. AN APPLICATION OBJECT. StaticResource falls back to Application.Current.Resources,
       which is what makes phase 1 and phase 2 differ at all.

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
    [string] $Playnite = 'F:\Playnite',
    # Run only phase 1. Faster, and it is the phase that decides whether the theme loads.
    [switch] $PreFlight
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
    $fwd = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath,'-Source',$Source,'-Playnite',$Playnite)
    if ($PreFlight) { $fwd += '-PreFlight' }
    & $wow @fwd
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
Write-Host "context: merged $context dictionaries from Playnite, 0 from the theme"
if ($context -lt 40) {
    Write-Host "FAIL  Playnite context barely merged - results would be meaningless. Check -Playnite."
    exit 2
}

$files = @(Get-OrderedXaml $Source -SkipLocalization)
$loc = Join-Path $Source 'Localization'
if (Test-Path $loc) { $files += Get-ChildItem $loc -Filter *.xaml }

$expected = 'Media.xaml'   # {ThemeFile} cannot resolve outside a deployed theme dir


function Get-MergeOrder([string] $playnite) {
    # App.xaml's merge list survives in the BAML as ordered relative paths.
    $exe = Join-Path $playnite 'Playnite.DesktopApp.exe'
    if (-not (Test-Path $exe)) { return @() }
    $bytes = [IO.File]::ReadAllBytes($exe)
    $ascii = [Text.Encoding]::ASCII.GetString($bytes)
    $seen = New-Object Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($ascii, 'Themes/Desktop/Default/(?:[A-Za-z]+/)?[A-Za-z]+\.xaml')) {
        $rel = ($m.Value -replace '^Themes/Desktop/Default/', '') -replace '/', '\'
        if (-not $seen.Contains($rel)) { $seen.Add($rel) }
    }
    return $seen
}

function Load-InScope($stream, $scope, $base) {
    # Parse with only ($base + $scope) in Application resources, so StaticResource sees exactly
    # what ApplyTheme would have merged so far.
    #
    # $base is Playnite's Templates\Themes and Localization. Those are NOT part of App.xaml's
    # theme merge list - they are already in the app when ApplyTheme runs - so clearing them
    # invents failures. It flagged LOCSaveLabel, LOCInstallGame and False on a tree that was
    # fine; keep them pinned.
    $app = [Windows.Application]::Current
    $saved = @($app.Resources.MergedDictionaries)
    $app.Resources.MergedDictionaries.Clear()
    foreach ($d in $base) { $app.Resources.MergedDictionaries.Add($d) }
    $app.Resources.MergedDictionaries.Add($scope)
    try { [Windows.Markup.XamlReader]::Load($stream) }
    finally {
        $app.Resources.MergedDictionaries.Clear()
        foreach ($d in $saved) { $app.Resources.MergedDictionaries.Add($d) }
    }
}

function Show-Error($rel, $ex) {
    $message = $ex.Message -replace "`r?`n", ' '
    $inner = $ex.InnerException
    while ($inner) { $message += "  <-- " + ($inner.Message -replace "`r?`n", ' '); $inner = $inner.InnerException }
    if ($message.Length -gt 300) { $message = $message.Substring(0, 300) + '...' }
    Write-Host "FAIL  $rel"
    Write-Host "      $message"
}

# ---------------- PHASE 1: pre-flight ----------------
# Exactly ApplyTheme's pre-flight: parse every file with NOTHING of the theme's own merged.
# A failure here is a theme-killer, so this phase alone decides the exit code.
Write-Host ''
Write-Host 'phase 1: pre-flight (no theme dictionaries merged)'
$preFail = 0; $preKnown = 0; $prePass = 0
foreach ($file in $files) {
    $rel = $file.FullName.Substring($Source.Length + 1)
    try {
        $stream = [IO.File]::OpenRead($file.FullName)
        try { [void][Windows.Markup.XamlReader]::Load($stream) } finally { $stream.Dispose() }
        $prePass++
    } catch {
        if ($file.Name -eq $expected) {
            $preKnown++
            Write-Host "known $rel (hard rule 7: {ThemeFile} needs a deployed theme dir)"
        } else { $preFail++; Show-Error $rel $_.Exception }
    }
}
Write-Host "  parsed: $prePass    expected failures: $preKnown    THEME-KILLERS: $preFail"

if ($PreFlight) {
    Write-Host ''
    if ($preFail -gt 0) { Write-Host "FAIL  $preFail file(s) would drop the user to Playnite's default theme"; exit 1 }
    Write-Host 'ok    pre-flight clean'
    exit 0
}

# ---------------- PHASE 1b: merge order ----------------
# ApplyTheme's SECOND pass (Themes.cs:197) re-loads each file while merging progressively, so a
# file sees only what App.xaml merged BEFORE it. That pass is NOT inside the pre-flight try/catch:
# a throw there does not fall back to the default theme, it stops Playnite from starting.
#
# This is what catches BasedOn="{StaticResource {x:Type Border}}" in Common.xaml - position 2,
# while DefaultControls/Border.xaml is 4 and Label.xaml is 16. Phase 1 misses it because it has
# Playnite's whole default theme in scope.
Write-Host ''
Write-Host 'phase 1b: merge order (each file sees only what App.xaml merged before it)'
$order = Get-MergeOrder $Playnite
if ($order.Count -lt 40) {
    Write-Host "  skipped - could not read App.xaml's merge order from the binary"
} else {
    $ordFail = 0; $ordPass = 0; $ordKnown = 0
    $acc = New-Object Windows.ResourceDictionary
    # Playnite's own globals stay in scope throughout - see Load-InScope.
    $baseScope = @()
    foreach ($root in 'Templates\Themes','Localization') {
        $d = Join-Path $Playnite $root
        if (-not (Test-Path $d)) { continue }
        foreach ($f in Get-ChildItem $d -Recurse -Filter *.xaml) {
            try { $s2=[IO.File]::OpenRead($f.FullName)
                  try { $rd2=[Windows.Markup.XamlReader]::Load($s2) } finally { $s2.Dispose() }
                  if ($rd2 -is [Windows.ResourceDictionary]) { $baseScope += $rd2 } } catch {}
        }
    }
    foreach ($rel in $order) {
        foreach ($root in @((Join-Path $Playnite 'Themes\Desktop\Default'), $Source)) {
            $full = Join-Path $root $rel
            if (-not (Test-Path $full)) { continue }
            $isTheme = ($root -eq $Source)
            try {
                $stream = [IO.File]::OpenRead($full)
                try { $dict = Load-InScope $stream $acc $baseScope } finally { $stream.Dispose() }
                if ($isTheme) { $ordPass++ }
                if ($dict -is [Windows.ResourceDictionary]) { $acc.MergedDictionaries.Add($dict) }
            } catch {
                if (-not $isTheme) { continue }          # Playnite's own file; not our problem
                if ((Split-Path $rel -Leaf) -eq $expected) { $ordKnown++; continue }
                $ordFail++
                Write-Host "FAIL  $rel  (merged at position $($order.IndexOf($rel)+1))"
                Show-Error $rel $_.Exception
            }
        }
    }
    Write-Host "  theme files loaded in order: $ordPass    expected: $ordKnown    STARTUP-KILLERS: $ordFail"
    $preFail += $ordFail
}

# ---------------- PHASE 2: runtime ----------------
# Merge as we go and force every value to realize - roughly the state after ApplyTheme
# succeeds. Catches deferred breakage pre-flight legitimately cannot see.
Write-Host ''
Write-Host 'phase 2: runtime (merge as we go, force realization)'
$runFail = 0; $runKnown = 0; $runPass = 0
foreach ($file in $files) {
    $rel = $file.FullName.Substring($Source.Length + 1)
    try {
        $stream = [IO.File]::OpenRead($file.FullName)
        try { $dict = [Windows.Markup.XamlReader]::Load($stream) } finally { $stream.Dispose() }
        if ($dict -is [Windows.ResourceDictionary]) {
            foreach ($key in @($dict.Keys)) { $null = $dict[$key] }
            $app.Resources.MergedDictionaries.Add($dict)
        }
        $runPass++
    } catch {
        if ($file.Name -eq $expected) { $runKnown++ }
        else { $runFail++; Show-Error $rel $_.Exception }
    }
}
Write-Host "  realized: $runPass    expected failures: $runKnown    unexpected: $runFail"

Write-Host ''
if ($preFail -gt 0) { Write-Host "FAIL  $preFail pre-flight failure(s) - the theme would not load at all"; exit 1 }
if ($runFail -gt 0) { Write-Host "FAIL  $runFail runtime failure(s)"; exit 1 }
Write-Host 'ok    both phases clean'
exit 0
