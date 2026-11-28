# My DTF — lecture seule de la fenêtre PrintExp (Windows UI Automation) et rapport de diagnostic.
# Ne clique sur rien, ne tape rien, n'envoie aucune commande : lit seulement les propriétés des éléments.
#   -Json            : liste des éléments (nom, id, type, valeur) en JSON pour le collecteur
#   -Report <dossier>: rapport complet (version de PrintExp, dossiers de journaux, arbre de la fenêtre)
param([string]$Process = 'PrintExp', [switch]$Json, [string]$Report)
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

function Get-Elements($procs) {
  $out = New-Object System.Collections.ArrayList
  foreach ($p in $procs) {
    $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $p.Id)
    $wins = [System.Windows.Automation.AutomationElement]::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
    foreach ($w in $wins) {
      $all = $w.FindAll([System.Windows.Automation.TreeScope]::Subtree, [System.Windows.Automation.Condition]::TrueCondition)
      foreach ($e in $all) {
        $c = $e.Current; $val = $null
        try { $vp = $e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern); $val = $vp.Current.Value } catch {}
        [void]$out.Add([pscustomobject]@{ window = $w.Current.Name; name = $c.Name; id = $c.AutomationId; type = $c.ControlType.ProgrammaticName; cls = $c.ClassName; value = $val; offscreen = $c.IsOffscreen })
      }
    }
  }
  return $out
}

$procs = Get-Process | Where-Object { $_.ProcessName -like "*$Process*" }

if ($Json) {
  $els = Get-Elements $procs | Where-Object { $_.name -or $_.value } | Select-Object name, id, type, value
  if ($els) { $els | ConvertTo-Json -Compress -Depth 3 } else { '[]' }
  exit 0
}

if ($Report) {
  New-Item -ItemType Directory -Force -Path $Report | Out-Null
  $f = Join-Path $Report 'printexp-rapport.txt'
  $lines = New-Object System.Collections.ArrayList
  [void]$lines.Add("My DTF — diagnostic PrintExp  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
  [void]$lines.Add("Windows : $([Environment]::OSVersion.VersionString)")
  [void]$lines.Add('')
  [void]$lines.Add('== Processus ==')
  foreach ($p in $procs) {
    $path = $p.Path; $ver = (Get-Item $path).VersionInfo
    [void]$lines.Add("$($p.ProcessName) pid=$($p.Id) fenêtre='$($p.MainWindowTitle)' minimisée? voir arbre")
    [void]$lines.Add("  exe=$path")
    [void]$lines.Add("  version fichier=$($ver.FileVersion) produit=$($ver.ProductName) $($ver.ProductVersion) société=$($ver.CompanyName)")
  }
  if (-not $procs) { [void]$lines.Add("PrintExp n'est pas ouvert. Ouvrez-le puis relancez le diagnostic.") }

  [void]$lines.Add(''); [void]$lines.Add('== Dossiers candidats (journaux, historique, rapports) ==')
  $roots = @()
  foreach ($p in $procs) { if ($p.Path) { $roots += Split-Path $p.Path } }
  $roots += @("$env:ProgramFiles", "${env:ProgramFiles(x86)}", "$env:ProgramData", "$env:APPDATA", "$env:LOCALAPPDATA", 'C:\', 'D:\') | ForEach-Object { Get-ChildItem $_ -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'hoson|printexp|audley|print' } | ForEach-Object FullName }
  foreach ($r in ($roots | Sort-Object -Unique)) {
    [void]$lines.Add("[$r]")
    Get-ChildItem $r -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '\.(log|txt|csv|xml|ini|json|db|mdb|sqlite|dat|his|rec)$' } |
      Sort-Object LastWriteTime -Descending | Select-Object -First 60 |
      ForEach-Object { [void]$lines.Add(("  {0:yyyy-MM-dd HH:mm}  {1,10} o  {2}" -f $_.LastWriteTime, $_.Length, $_.FullName)) }
  }

  [void]$lines.Add(''); [void]$lines.Add('== Arbre UI Automation de la fenêtre PrintExp ==')
  foreach ($e in (Get-Elements $procs)) {
    [void]$lines.Add(("{0} | {1} | id={2} | cls={3} | nom='{4}' | valeur='{5}' | horsEcran={6}" -f $e.window, $e.type, $e.id, $e.cls, $e.name, $e.value, $e.offscreen))
  }
  $lines | Set-Content -Path $f -Encoding UTF8
  # Copie des 3 journaux les plus récents (s'ils existent) pour écrire les règles de lecture.
  $copy = Join-Path $Report 'journaux'; New-Item -ItemType Directory -Force -Path $copy | Out-Null
  foreach ($r in ($roots | Sort-Object -Unique)) {
    Get-ChildItem $r -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '\.(log|txt|csv|xml|his|rec)$' -and $_.Length -lt 20MB } |
      Sort-Object LastWriteTime -Descending | Select-Object -First 3 | ForEach-Object { Copy-Item $_.FullName (Join-Path $copy ($_.Directory.Name + '__' + $_.Name)) -ErrorAction SilentlyContinue }
  }
  Write-Output $f
}
