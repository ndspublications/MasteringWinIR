$StartTime = Get-Date
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()


param(
  [ValidateRange(1,365)]
  [int]$TimeSpan = 30]
  )

param(
  [string]$OutputLog
  )

  if (-not $OutputLog){ 
    $OutputLog = (Get-Date -Format "yyyy_MMdd_HHmmss") + ".log"
    }

    

  $cutoff = (Get-Date).AddDays(-$TimeSpan)

  Get-VM |
  Where-Object {$_.CreationTime -ge $cutoff)} |
  Select-Object Name, State, Uptime, CreationTime | 
  Sort-Object CreationTime

$Stopwatch.Stop()
$EndTime = Get-Date
$DurationMs = $Stopwatch.Elapsed
$VmCount = $VMs.Count

$Summary = @"
Execution Summary
---------------------------
Start Time:      $StartTime
End Time:        $EndTime
Duration:        $($Duration.ToString())
VMs Processed:   $VmCount
TimeSpan (Days): $TimeSpan
"@

$Summary | Tee-Object -FilePath $OutputLog -Append

  
  
