param(
    [Parameter(Mandatory=$true)]
    [string]$AddonName
)

if (-not (Test-Path $AddonName -PathType Container)) {
    Write-Error "Error: Directory '$AddonName' not found."
    exit 1
}

# Extract version from first .toc file that contains a Version field
$version = $null
foreach ($toc in Get-ChildItem "$AddonName\*.toc") {
    $match = Select-String -Path $toc -Pattern '^## Version: (.+)$' | Select-Object -First 1
    if ($match) {
        $version = $match.Matches[0].Groups[1].Value.Trim()
        break
    }
}

if (-not $version) {
    Write-Error "Error: No '## Version:' found in .toc files."
    exit 1
}

if (-not (Test-Path "release" -PathType Container)) {
    New-Item -ItemType Directory -Path "release" | Out-Null
}

$zipName = "release\$AddonName-$version.zip"

if (Test-Path $zipName) {
    Remove-Item $zipName
}

Compress-Archive -Path $AddonName -DestinationPath $zipName

Write-Host "Created $zipName"
