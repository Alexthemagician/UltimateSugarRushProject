$prototypePath = $PSScriptRoot
$godotPath = 'D:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe'
if (-not (Test-Path -LiteralPath $godotPath)) {
    throw 'Open this folder''s project.godot in Godot 4.7 to run the café study.'
}
& $godotPath --path $prototypePath
