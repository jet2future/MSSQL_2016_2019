$ErrorActionPreference = "Stop"
$server = "$(ESCAPE_DQUOTE(SRVR))"
$sampleInterval = 1
$maxSamples = 15
$numberOfHeaderRowsToSkip = 1
$date = Get-Date
$reportBody = "<h4>Report as of $date</h4>"
$mailServer = "YOURSMTPSERVER"
$mailFrom = "from@domain.com"
$mailTo = "to@domain.com"
$mailSubject = "$(ESCAPE_DQUOTE(SRVR)) email subject"
$reportHeader = "<style>
th {border:solid black 1px; border-collapse:collapse; padding-left:5px; padding-right:5px; padding-top:1px; padding-bottom:1px; background-color:white;}
td {border:solid black 1px; border-collapse:collapse; padding-left:5px; padding-right:5px; padding-top:1px; padding-bottom:1px; color:black; vertical-align: top;}
tr.even {background-color: #lightgray}</style>"
$perfMonExclusions = @("SERVERDEV01")
$perfMonExclusionsProcessor = @()
$perfMonExclusionsMemory = @()
$perfMonExclusionsDisk = @()
$perfMonExclusionsNetwork = @()
if (-Not ($perfMonExclusions -contains $server)) {
   $list = New-Object System.Collections.Generic.List[System.Object]
   $computerName = $server
   if ($computerName.Contains("\")) {
      $computerName = $computerName.Substring(0, $computerName.IndexOf("\"))
   }
   $result2 = New-Object System.Data.DataTable
   $result2.Columns.Add("LogDate", "System.DateTime") | Out-Null
   $result2.Columns.Add("Text", "System.String") | Out-Null
   $curDate = (Get-Date).ToString()
   [System.Collections.ArrayList]$counters = @()
   $counters += "\\$computerName\VM Processor(_Total)\% Processor Time"
   $counters += "\\$computerName\VM Processor(_Total)\CPU Stolen Time"
   $counters += "\\$computerName\VM Memory\Memory Ballooned in MB"
   $counters += "\\$computerName\VM Memory\Memory Swapped in MB"
   $prefix = ""
   if (!$server.contains("\")) {
      $prefix = "\\$computerName\SQLServer"
   }
   else {
      $prefix = "\\$computerName\MSSQL$" + $server.Substring($server.IndexOf("\") + 1)
   }
   $counters += ($prefix + ":Buffer Manager\total pages")
   $counters += ($prefix + ":Buffer Manager\Page life expectancy")
   $counters += ($prefix + ":Memory Node(000)\Total Node Memory (KB)")
   try {
      # counters that may vary: VM-related, buffer manager, etc.
      $availCounters = powershell.exe -command "Get-Counter -ComputerName$computerName -ListSet * | select -expand Counter"
      $availCounters = $availCounters | foreach {if ($_ -inotmatch [RegEx]::Escape("Memory Node(*)")) {$_.replace('(*)', '(_Total)')} else {$_.replace('(*)', '(000)')}} | where {$counters -contains $_} | foreach {"'$_'"}
      if (-Not ($availCounters -contains ("'" + $prefix + ":Buffer Manager\Page life expectancy'"))) {
         throw "Some SQL Server perf counters are unavailable, exiting"
      }
      $availCounters = $availCounters -join ","
      # counters that must exist
      $availCounters += ",'\\$computerName\System\Processor Queue Length'"
      $availCounters += ",'\\$computerName\Processor(_Total)\% Processor Time'"
      $availCounters += ",'\\$computerName\Processor(_Total)\% Privileged Time'"
      $availCounters += ",'\\$computerName\Process(*)\% Processor Time'"
      $availCounters += ",'\\$computerName\Memory\Available Bytes'"
      $availCounters += ",'\\$computerName\Process(*)\Working Set'"
      $availCounters += ",'\\$computerName\Memory\Cache Bytes'"
      $availCounters += ",'\\$computerName\Memory\Pool Nonpaged Bytes'"
      $availCounters += ",'\\$computerName\Paging File(_Total)\% Usage'"
      $availCounters += ",'\\$computerName\Memory\Pages/sec'"
      $availCounters += ",'\\$computerName\PhysicalDisk(*)\Avg. Disk sec/Read'"
      $availCounters += ",'\\$computerName\PhysicalDisk(*)\Avg. Disk sec/Write'"
      $availCounters += ",'\\$computerName\PhysicalDisk(*)\Disk Bytes/sec'"
      $availCounters += ",'\\$computerName\PhysicalDisk(*)\Current Disk Queue Length'"
      $availCounters += ",'\\$computerName\Network Interface(*)\Bytes Received/sec'"
      $availCounters += ",'\\$computerName\Network Interface(*)\Bytes Sent/sec'"
      $availCounters += ",'\\$computerName\Network Interface(*)\Current Bandwidth'"
      $availCounters += ",'\\$computerName\Network Interface(*)\Output Queue Length'"
      $availCounters += ",'\\$computerName\Network Interface(*)\Packets Outbound Errors'"
      $availCounters += ",'\\$computerName\Network Interface(*)\Packets Received Errors'"
      $availCounters += ",'\\$computerName\Process(*)\IO Data Bytes/sec'"
      $results = powershell.exe -command "`$Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(500,300); Get-Counter -ComputerName$computerName -Counter @($availCounters) -SampleInterval$sampleInterval -MaxSamples$maxSamples -ErrorAction SilentlyContinue | select -ExpandProperty CounterSamples | select Path, '|', CookedValue | Format-Table -Property * -AutoSize | Out-String -Width 500"
      if ($results[0].Contains("The specified counter path could not be interpreted")) {
         throw "Some perf counters are unavailable, exiting"
      }
      $pos = $results[1].IndexOf("|")
      $results2 = $results | where {$_.StartsWith("\\")} | select @{l="Path";e={$_.Substring(0, $pos).Trim()}}, @{l="CookedValue";e={$_.Substring($pos, $_.length - $pos).Trim()}}
      $results = @{}
      foreach ($result in $results2) {
         if (!$results.ContainsKey($result.Path)) {
            $results.($result.Path) = [math]::Round(($results2 | where {$_.Path -eq $result.Path} | Measure-Object -Property CookedValue -Average).Average, 2)
         }
      }
      # Processor
      if (-Not ($perfMonExclusionsProcessor -contains $server)) {
         $cores = (Get-WmiObject Win32_Processor -computer $computerName | select SocketDesignation | Measure-Object).Count
         if ($results["\\$computerName\System\Processor Queue Length"] -gt $cores) {
            if ($results["\\$computerName\Processor(_Total)\% Processor Time"] -gt 80 `
            -Or $results["\\$computerName\Processor(_Total)\% Privileged Time"] -gt 80 `
            -Or $results["\\$computerName\VM Processor(_Total)\% Processor Time"] -gt 80) {
               $ProcessorQueueLength = $results["\\$computerName\System\Processor Queue Length"]
               $newRow = $result2.NewRow()
               $newRow.LogDate = $curDate
               $newRow.Text = "Processor Queue Length$ProcessorQueueLength >$cores cores and Processor/Privileged Time > 80%"
               $result2.Rows.Add($newRow)
               $TopCPUKey = ""
               $TopCPUValue = 0
               foreach ($r2 in ($results.Keys | where {$_.EndsWith("% processor time")})) {
                  if ($results[$r2] -gt $TopCPUValue -And !$r2.Contains("(_total)") -And !$r2.Contains("(idle)")) {
                     $TopCPUKey = $r2
                     $TopCPUValue = $results[$r2]
                  }
               }
               $TopCPUKey = [regex]::match($TopCPUKey,'\(([^\)]+)\)').Groups[1].Value
               $TopCPUValue = [math]::Round($TopCPUValue, 2)
               $newRow = $result2.NewRow()
               $newRow.LogDate = $curDate
               $newRow.Text = "Top CPU consumer: '$TopCPUKey' with$TopCPUValue %"
               $result2.Rows.Add($newRow)
            }
         }
         if ($results["\\$computerName\VM Processor(_Total)\CPU Stolen Time"] -gt 40) {
            $CPUStolenTime = $results["\\$computerName\VM Processor(_Total)\CPU Stolen Time"]
            $newRow = $result2.NewRow()
            $newRow.LogDate = $curDate
            $newRow.Text = "VM CPU Stolen Time$CPUStolenTime > 40 ms"
            $result2.Rows.Add($newRow)
         }
      }
      # Memory
      if (-Not ($perfMonExclusionsMemory -contains $server)) {
         $MemUsage = 0
         if (!$results["\\$computerName\Memory\Available Bytes"] -Or !$results["\\$computerName\Process(_Total)\Working Set"] -Or !$results["\\$computerName\Memory\Cache Bytes"] -Or !$results["\\$computerName\Memory\Pool Nonpaged Bytes"]) {
            $MemUsage = 91
         }
         else {
            $MemUsage = 100 - ($results["\\$computerName\Memory\Available Bytes"] / ($results["\\$computerName\Memory\Available Bytes"] + $results["\\$computerName\Process(_Total)\Working Set"] + $results["\\$computerName\Memory\Cache Bytes"] + $results["\\$computerName\Memory\Pool Nonpaged Bytes"]) * 100)
         }
         if ($MemUsage -gt 90 `
         -And $results["\\$computerName\Paging File(_Total)\% Usage"] -gt 90 `
         -And $results["\\$computerName\Memory\Pages/sec"] -gt 25) {
            $PagingFile = $results["\\$computerName\Paging File(_Total)\% Usage"]
            $PagesSec = $results["\\$computerName\Memory\Pages/sec"]
            $newRow = $result2.NewRow()
            $newRow.LogDate = $curDate
            $newRow.Text = "RAM Utilization is$MemUsage % and Page File Utilization is$PagingFile % and Memory Pages Per Second$PagesSec > 25 pps"
            $result2.Rows.Add($newRow)
            $TopMemKey = ""
            $TopMemValue = 0
            foreach ($r2 in ($results.Keys | where {$_.EndsWith("working set")})) {
               if ($results[$r2] -gt $TopMemValue -And !$r2.Contains("(_total)") -And !$r2.Contains("(idle)")) {
                  $TopMemKey = $r2
                  $TopMemValue = $results[$r2]
               }
            }
            $TopMemKey = [regex]::match($TopMemKey,'\(([^\)]+)\)').Groups[1].Value
            $TopMemValue = [math]::Round($TopMemValue, 2)
            $newRow = $result2.NewRow()
            $newRow.LogDate = $curDate
            $newRow.Text = "Top memory consumer: '$TopMemKey' with$TopMemValue bytes"
            $result2.Rows.Add($newRow)
         }
         if ($results["\\$computerName\VM Memory\Memory Ballooned in MB"] -gt 512) {
            $MemBallooned = $results["\\$computerName\VM Memory\Memory Ballooned in MB"]
            $newRow = $result2.NewRow()
            $newRow.LogDate = $curDate
            $newRow.Text = "VM Memory Ballooned is " + $MemBallooned + " MB and can't be used"
            $result2.Rows.Add($newRow)
         }
         if ($results["\\$computerName\VM Memory\Memory Swapped in MB"] -gt 512) {
            $MemSwapped = $results["\\$computerName\VM Memory\Memory Swapped in MB"]
            $newRow = $result2.NewRow()
            $newRow.LogDate = $curDate
            $newRow.Text = "VM Memory Swapped is " + $MemSwapped + "MB and can't be used"
            $result2.Rows.Add($newRow)
         }
         $TotalMemoryMB = $results[$prefix + ":Memory Node(000)\Total Node Memory (KB)"] / 1000
         if (!$TotalMemoryMB) {
            $TotalMemoryMB = $results[$prefix + ":Buffer Manager\total pages"] / 128
         }
         $PageLifeExpectancy = $results[$prefix + ":Buffer Manager\Page life expectancy"]
         if ($TotalMemoryMB -And $PageLifeExpectancy) {
            $TotalMemoryMB = [math]::Round($TotalMemoryMB, 2)
            $BufferPoolRate = [math]::Round($TotalMemoryMB / $PageLifeExpectancy, 2)
            if ($BufferPoolRate -gt 20) {
               $newRow = $result2.NewRow()
               $newRow.LogDate = $curDate
               $newRow.Text = "Buffer Pool Rate$BufferPoolRate > 20 MB/sec. Memory:$TotalMemoryMB PLE:$PageLifeExpectancy"
               $result2.Rows.Add($newRow)
            }
         }
      }
      $IOissuesFound = 0
      # Disk
      if (-Not ($perfMonExclusionsDisk -contains $server)) {
         foreach ($r in ($results.Keys | where {($_.EndsWith("avg. disk sec/read") -Or $_.EndsWith("avg. disk sec/write")) -And !$_.Contains("(_total)")})) {
            $counter = $r.Substring($r.LastIndexOf("\") + 1)
            if ($results[$r] -gt 0.015) {
               $IOissuesFound = 1
               $drive = [regex]::match($r,'\(([^\)]+)\)').Groups[1].Value
               $val = $results[$r]
               $newRow = $result2.NewRow()
               $newRow.LogDate = $curDate
               $newRow.Text = "'$drive'$counter$val > 0.015 sec"
               $result2.Rows.Add($newRow)
               $complement = $r
               if ($counter.EndsWith("read")) {
                  $complement = $complement.Replace("read", "write")
               }
               else {
                  $complement = $complement.Replace("write", "read")
               }
               if ($results[$complement] -gt 0.015) {
                  $counter2 = $complement.Substring($complement.LastIndexOf("\") + 1)
                  $val = $results[$complement]
                  $newRow = $result2.NewRow()
                  $newRow.LogDate = $curDate
                  $newRow.Text = "'$drive'$counter2$val > 0.015 sec"
                  $result2.Rows.Add($newRow)
                  $results[$complement] = 0
               }
               $DiskBytesSec = $results["\\$computerName\PhysicalDisk($drive)\Disk Bytes/sec"]
               if ($DiskBytesSec -lt 204800) {
                  $newRow = $result2.NewRow()
                  $newRow.LogDate = $curDate
                  $newRow.Text = "'$drive' bytes/sec$DiskBytesSec < 204800"
                  $result2.Rows.Add($newRow)
               }
               $CurDiskQueueLength = $results["\\$computerName\PhysicalDisk($drive)\Current Disk Queue Length"]
               $newRow = $result2.NewRow()
               $newRow.LogDate = $curDate
               $newRow.Text = "'$drive' current queue length$CurDiskQueueLength"
               $result2.Rows.Add($newRow)
            }
         }
      }
      # Network
      if (-Not ($perfMonExclusionsNetwork -contains $server)) {
         foreach ($r in ($results.Keys | where {$_.EndsWith("current bandwidth") -And !$_.Contains("(_total)")})) {
            $interface = [regex]::match($r,'\(([^\)]+)\)').Groups[1].Value
            $bandwidth = $results[$r]/8
            $val = $results[$r.Replace("current bandwidth", "bytes received/sec")]
            $NetworkIssuesFound = 0
            if ($val -gt $bandwidth*0.8) {
               $NetworkIssuesFound = 1
               $IOIssuesFound = 1
               $newRow = $result2.NewRow()
               $newRow.LogDate = $curDate
               $newRow.Text = "'$interface' bytes received/sec$val > 80% bandwidth"
               $result2.Rows.Add($newRow)
            }
            $val = $results[$r.Replace("current bandwidth", "bytes sent/sec")]
            if ($val -gt $bandwidth*0.8) {
               $NetworkIssuesFound = 1
               $IOIssuesFound = 1
               $newRow = $result2.NewRow()
               $newRow.LogDate = $curDate
               $newRow.Text = "'$interface' bytes sent/sec$val > 80% bandwidth"
               $result2.Rows.Add($newRow)
            }
            if ($NetworkIssuesFound) {
               $val = $results[$r.Replace("current bandwidth", "output queue length")]
               if ($val -gt 2) {
                  $newRow = $result2.NewRow()
                  $newRow.LogDate = $curDate
                  $newRow.Text = "'$interface' output queue length$val > 2"
                  $result2.Rows.Add($newRow)
               }
               $val = $results[$r.Replace("current bandwidth", "packets outbound errors")]
               if ($val -gt 0) {
                  $newRow = $result2.NewRow()
                  $newRow.LogDate = $curDate
                  $newRow.Text = "'$interface' packets outbound errors$val"
                  $result2.Rows.Add($newRow)
               }
               $val = $results[$r.Replace("current bandwidth", "packets received errors")]
               if ($val -gt 0) {
                  $newRow = $result2.NewRow()
                  $newRow.LogDate = $curDate
                  $newRow.Text = "'$interface' packets received errors$val"
                  $result2.Rows.Add($newRow)
               }
            }
         }
      }
      # Disk / Network
      if (-Not ($perfMonExclusionsDisk -contains $server -And $perfMonExclusionsNetwork -contains $server)) {
         if ($IOissuesFound) {
            $TopIOKey = ""
            $TopIOValue = 0
            foreach ($r2 in ($results.Keys | where {$_.EndsWith("io data bytes/sec")})) {
               if ($results[$r2] -gt $TopIOValue -And !$r2.Contains("(_total)")) {
                  $TopIOKey = $r2
                  $TopIOValue = $results[$r2]
               }
            }
            $TopIOKey = [regex]::match($TopIOKey,'\(([^\)]+)\)').Groups[1].Value
            $TopIOValue = [math]::Round($TopIOValue, 2)
            $newRow = $result2.NewRow()
            $newRow.LogDate = $curDate
            $newRow.Text = "Top I/O consumer (file, network and device): '$TopIOKey' with$TopIOValue bytes/sec"
            $result2.Rows.Add($newRow)
         }
      }
   }
   catch {
      $newRow = $result2.NewRow()
      $newRow.LogDate = $curDate
      $newRow.Text = " at line " + $_.InvocationInfo.ScriptLineNumber + " " + $_.Exception.Message
      $result2.Rows.Add($newRow)
   }
   if ($result2.Rows.Count -gt 0) {
      foreach ($r in ($result2 | select LogDate, Text)) { $list.add($r) }
   }
}
if ($list -eq $NULL -or $list.count -eq 0) {
  exit
}
[string]$result = $list | ConvertTo-HTML -Fragment | Out-String
[xml]$result = $result.Replace("`0", "")
for ($i = 0; $i -lt $result.table.tr.count - $numberOfHeaderRowsToSkip; $i++) {
  $class = $result.CreateAttribute("class")
  $class.value = if($i % 2 -eq 0) {"even"} else {"odd"}
  $result.table.tr[$i+$numberOfHeaderRowsToSkip].attributes.append($class) | Out-Null
}
$reportBody += $result.InnerXml
$message = New-Object System.Net.Mail.MailMessage $mailFrom, $mailTo
$message.Subject = $mailSubject
$message.IsBodyHTML = $true
$message.Body = ConvertTo-HTML -head $reportHeader -body $reportBody
$smtp = New-Object Net.Mail.SmtpClient($mailServer)
$smtp.Send($message)
$message.Dispose() 
