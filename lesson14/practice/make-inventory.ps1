$ErrorActionPreference = "Stop"

Write-Host "Getting IP from Terraform..." -ForegroundColor Cyan

$tfDir = "$PSScriptRoot\..\..\lesson11\practice"
Push-Location $tfDir

try {
    $ip = terraform output -raw public_ip
} catch {
    Write-Host "Error: Could not get IP. Make sure VM is created." -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location

if (-not $ip) {
    Write-Host "Error: IP is empty." -ForegroundColor Red
    exit 1
}

Write-Host "VM IP: $ip" -ForegroundColor Yellow

$inventoryContent = @"
[web]
web01 ansible_host=$ip ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_ed25519
"@

$inventoryContent | Out-File -FilePath "$PSScriptRoot\inventory.ini" -Encoding ascii

Write-Host "inventory.ini updated successfully!" -ForegroundColor Green
Write-Host "inventory.ini updated successfully!" -ForegroundColor Green