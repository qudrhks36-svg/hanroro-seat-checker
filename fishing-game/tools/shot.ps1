param([string]$Name, [string]$Args1, [int]$Port = 8140, [switch]$Export)
# 웹 내보내기(선택) → 시험 인자를 박은 복사본을 %TEMP%\shots\<Name>에 만들고 python 서버를 띄운다 (창 없음). 반환값 = 서버 프로세스 번호(끝나면 Stop-Process).
# 쓰는 법: .\tools\shot.ps1 -Name x -Args1 '"--perf=1"' -Port 8765 -Export  → 앱 안 브라우저로 http://localhost:8765/x/index.html
$g = "C:\Users\qudrh\OneDrive\바탕 화면\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if ($Export) {
  $elog = Join-Path $env:TEMP "g_export_shot.log"; if (Test-Path -LiteralPath $elog) { Remove-Item -LiteralPath $elog -Force }
  $p = Start-Process -FilePath $g -ArgumentList @("--headless","--path","C:\Users\qudrh\fishing-game-repo\fishing-game\godot","--export-release","Web","--log-file",$elog) -WindowStyle Hidden -PassThru -Wait
  "export exit={0} errors={1}" -f $p.ExitCode, ([regex]::Matches((Get-Content -LiteralPath $elog -Raw), "SCRIPT ERROR|ERROR:")).Count
}
$src = "C:\Users\qudrh\fishing-game-build\godot-web"
$root = Join-Path $env:TEMP "shots"
$d = Join-Path $root $Name
if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }
New-Item -ItemType Directory $d -Force | Out-Null
Get-ChildItem -LiteralPath $src -File | Copy-Item -Destination $d
$f = Join-Path $d "index.html"
$h = Get-Content -LiteralPath $f -Raw -Encoding UTF8
$h = $h.Replace('"args":[]', '"args":["--",' + $Args1 + ',"--nosave=1"]')
Set-Content -LiteralPath $f -Value $h -Encoding UTF8
$sp = Start-Process -FilePath python -ArgumentList @("-m","http.server","$Port","--directory",$root) -WindowStyle Hidden -PassThru
$sp.Id
