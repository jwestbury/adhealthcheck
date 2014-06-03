# def commands/paths
$repCmd = "repadmin /showrepl * /csv"
$outputPath = "\users\public\documents\logs"
$outputFileRepadmin = "Repadmin-"+(Get-Date -Format yyyyMMdd_hhmmss)+".csv"
$outputFileBpaStauts = "BpaReport-"+(Get-Date -Format yyyyMMdd_hhmmss)+".txt"

# def states hash for nagios evaluation - we'll add to this later and evaluate it for exit codes
$nagStates = @{}
$nagExitString = ""

# def CSV header
$Header = "showrepl_COLUMNS","Destination DSA Site","Destination DSA","Naming Context","Source DSA Site","Source DSA","Transport Type",`
            "Number of Failures","Last Failure Time","Last Success Time","Last Failure Status"

# create output path if it doesn't exist
if (!(test-path $outputPath)) { mkdir $outputPath }

# set initial state - 0, no error - for Repadmin
$nagStates.Set_Item("Repadmin", 0)

# run repadmin create csv
Invoke-Expression $repCmd | Out-File "$outputPath/$outputFileRepadmin"

# get info from the csv
$repadminCsv = Import-Csv -Path "$outputPath/$outputFileRepadmin"

# parse repadmin statuses, store errors
if ($repadminStatus = $repadminCsv | Where-Object { $_.showrepl_COLUMNS -notmatch "showrepl_INFO" }) {
    $nagExitString += "Errors in repadmin results. See log at $outputPath\$outputFileRepadmin on "+(hostname)+". "
    $nagStates.SetItem("Repadmin", 2)
} else {
    $nagExitString += "No errors found in repadmin results. "
}

# set initial state - 0, no error - for BPA
$nagStates.Set_Item("Bpa", 0)

# run best practices analyzer on directory services
Invoke-BpaModel -ModelId Microsoft/Windows/DirectoryServices
Get-BpaResult -ModelId Microsoft/Windows/DirectoryServices | ForEach-Object {
    if ($_.severity -eq "Error") { 
        $_ | Out-File -Append -FilePath "$outputPath\$outputFileBpaStatus"
        if ($nagStates.Get_Item("Bpa") -lt 2) { $nagStates.Set_Item("Bpa", 2); $nagExitString += "Best Practices Analyzer found errors. See log at $outputPath\$outputFileBpaStatus on "+(hostname)+". " }
    }
    elseif ($_.severity -eq "Warning") { 
        if ($nagStates.Get_Item("Bpa") -lt 1) { $nagStates.Set_Item("Bpa", 1) }
    }
}

# if we didn't find errors above, update our exit string
if ($nagStates.Get_Item("Bpa") -eq 0) { $nagExitString += "No errors found in Best Practices Analyzer results. " }

# test case - comment the next two lines in production
$nagStates.Set_Item("test", 2)
$nagExitString += "Test error present. "


# output our status message for Nagios
write-host $nagExitString

# evaluate our nagStates hash table and define our exit code
if ($nagStates.values -eq 2) { exit 2 }
elseif ($nagStates.values -eq 1) { exit 1 }
else { exit 0 }