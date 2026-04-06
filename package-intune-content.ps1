[CmdletBinding()]
param(
    [string]$OutputPath,
    [switch]$Clean,
    [switch]$IncludeReadme
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $OutputPath) {
    $OutputPath = Join-Path $PSScriptRoot 'dist\intune-content'
}

$filesToStage = @(
    'patch-github-copilot.ps1',
    'test-github-copilot-compliance.ps1',
    'intune-detect-github-copilot.ps1',
    'intune-remediate-github-copilot.ps1'
)

if ($Clean -and (Test-Path -LiteralPath $OutputPath)) {
    Remove-Item -LiteralPath $OutputPath -Recurse -Force
}

$null = New-Item -ItemType Directory -Path $OutputPath -Force

$stagedFiles = New-Object System.Collections.Generic.List[string]

foreach ($fileName in $filesToStage) {
    $sourcePath = Join-Path $PSScriptRoot $fileName
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required file not found: $sourcePath"
    }

    $destinationPath = Join-Path $OutputPath $fileName
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
    $stagedFiles.Add($destinationPath)
}

if ($IncludeReadme) {
    $documentationFiles = @(
        'README.md',
        'LICENSE',
        'disclaimer.md'
    )

    foreach ($documentationFile in $documentationFiles) {
        $documentationSource = Join-Path $PSScriptRoot $documentationFile
        if (Test-Path -LiteralPath $documentationSource -PathType Leaf) {
            Copy-Item -LiteralPath $documentationSource -Destination (Join-Path $OutputPath $documentationFile) -Force
        }
    }
}

$manifestPath = Join-Path $OutputPath 'package-manifest.txt'
$manifestLines = @(
    "Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ssK')",
    "Source: $PSScriptRoot",
    'Files:'
)

foreach ($fileName in $filesToStage) {
    $manifestLines += "- $fileName"
}

if ($IncludeReadme) {
    $manifestLines += '- README.md'
    $manifestLines += '- LICENSE'
    $manifestLines += '- disclaimer.md'
}

Set-Content -LiteralPath $manifestPath -Value $manifestLines

[pscustomobject]@{
    OutputPath    = $OutputPath
    StagedFiles   = $stagedFiles.ToArray()
    ManifestPath  = $manifestPath
    IncludedReadme = [bool]$IncludeReadme
}