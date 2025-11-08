$disk = "\\.\PHYSICALDRIVE0"
$part = 3
$arg  = "--mount $disk --partition $part --type btrfs"

$action  = New-ScheduledTaskAction -Execute "wsl.exe" -Argument $arg
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "WSL Attach Linux Disk" -Action $action -Trigger $trigger -RunLevel Highest -Description "Attach Linux disk for WSL"
