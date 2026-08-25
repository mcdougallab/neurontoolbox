param(
    [string]$ToolboxDir,
    [string]$HocDir,
    [string]$RuntimeDir,
    [string]$StartupFile,
    [string]$StartupLine,
    [string]$StateFile,
    [string]$AddedMatlabPath,
    [string]$AddedHocDir,
    [string]$AddedRuntimeDir,
    [string]$AddedStartupLine
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-Entry {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Value).Trim()
    if ($expanded.Length -eq 0) {
        return $null
    }

    return $expanded.TrimEnd('\').ToLowerInvariant()
}

function Remove-UserEnvEntry {
    param(
        [string]$Name,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $keyPath = "HKCU:\Environment"
    $current = (Get-ItemProperty -Path $keyPath -Name $Name -ErrorAction SilentlyContinue).$Name
    if ($null -eq $current) {
        Write-Host "  $Name not set, skipping"
        return
    }

    $target = Normalize-Entry $Value
    $parts = @($current -split ';' | Where-Object { $_ -and $_.Trim().Length -gt 0 })
    $kept = @($parts | Where-Object { (Normalize-Entry $_) -ne $target })

    if ($kept.Count -eq $parts.Count) {
        Write-Host "  Value not present in $Name, skipping"
        return
    }

    if ($kept.Count -eq 0) {
        Remove-ItemProperty -Path $keyPath -Name $Name -ErrorAction SilentlyContinue
        Write-Host "  Removed $Name"
    } else {
        Set-ItemProperty -Path $keyPath -Name $Name -Value ($kept -join ';')
        Write-Host "  Updated $Name"
    }
}

function Remove-StartupLine {
    param(
        [string]$Path,
        [string]$LineToRemove
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($LineToRemove)) {
        return
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "  startup.m not found, skipping"
        return
    }

    $lines = @(Get-Content -LiteralPath $Path)
    $kept = @($lines | Where-Object { $_.Trim() -ne $LineToRemove })

    if ($kept.Count -eq $lines.Count) {
        Write-Host "  startup.m entry not present, skipping"
        return
    }

    $nonEmpty = @($kept | Where-Object { $_.Trim().Length -gt 0 })
    if ($nonEmpty.Count -eq 0) {
        Remove-Item -LiteralPath $Path -Force
        Write-Host "  Removed empty startup.m"
    } else {
        Set-Content -LiteralPath $Path -Value $kept
        Write-Host "  Updated startup.m"
    }
}

if ($AddedMatlabPath -eq "1") {
    Remove-UserEnvEntry -Name "MATLABPATH" -Value $ToolboxDir
}
if ($AddedHocDir -eq "1") {
    Remove-UserEnvEntry -Name "HOC_LIBRARY_PATH" -Value $HocDir
}
if ($AddedRuntimeDir -eq "1") {
    Remove-UserEnvEntry -Name "PATH" -Value $RuntimeDir
}
if ($AddedStartupLine -eq "1") {
    Remove-StartupLine -Path $StartupFile -LineToRemove $StartupLine
}

$signature = @"
[DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
public static extern IntPtr SendMessageTimeoutW(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
$type = Add-Type -MemberDefinition $signature -Name "NativeMethods" -Namespace "NrnMl" -PassThru
$result = [UIntPtr]::Zero
[void]$type::SendMessageTimeoutW([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, "Environment", 2, 5000, [ref]$result)

if (-not [string]::IsNullOrWhiteSpace($StateFile) -and (Test-Path -LiteralPath $StateFile)) {
    Remove-Item -LiteralPath $StateFile -Force
    Write-Host "  Removed install state file"
}
