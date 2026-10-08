param(
    [switch]$Unregister,
    [string]$ExecutablePath
)

$scheme = 'com.chemvision.chemvision'
$protocolKey = "HKCU:\Software\Classes\$scheme"

if ($Unregister) {
    if (Test-Path -LiteralPath $protocolKey) {
        Remove-Item -LiteralPath $protocolKey -Recurse -Force
    }
    Write-Output "已移除 $scheme URL scheme。"
    exit 0
}

if (-not $ExecutablePath) {
    $sameDirectoryExecutable = Join-Path $PSScriptRoot 'ChemVision.exe'
    $buildOutputExecutable = Join-Path $PSScriptRoot '..\build\windows\x64\runner\Release\ChemVision.exe'
    if (Test-Path -LiteralPath $sameDirectoryExecutable) {
        $ExecutablePath = $sameDirectoryExecutable
    } else {
        $ExecutablePath = $buildOutputExecutable
    }
}

$resolvedExecutable = (Resolve-Path -LiteralPath $ExecutablePath -ErrorAction Stop).Path
New-Item -Path $protocolKey -Force | Out-Null
Set-Item -LiteralPath $protocolKey -Value 'URL:ChemVision authentication callback'
New-ItemProperty -LiteralPath $protocolKey -Name 'URL Protocol' -Value '' -PropertyType String -Force | Out-Null
$commandKey = Join-Path $protocolKey 'shell\open\command'
New-Item -Path $commandKey -Force | Out-Null
Set-Item -LiteralPath $commandKey -Value ('"{0}" "%1"' -f $resolvedExecutable)

Write-Output "已将 $scheme 注册到 $resolvedExecutable。"
Write-Output '如需移除，请运行：powershell -ExecutionPolicy Bypass -File .\register_auth_protocol.ps1 -Unregister'
