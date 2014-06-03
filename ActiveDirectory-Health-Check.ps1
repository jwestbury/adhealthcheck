# def commands/paths
$repCmd = "repadmin /showrepl * /csv"
$outputPath = "\users\public\documents\logs"
$outputFileRepadmin = "Repadmin-"+(Get-Date -Format yyyyMMdd_hhmmss)+".csv"
$outputFileBpaStauts = "BpaReport-"+(Get-Date -Format yyyyMMdd_hhmmss)+".txt"

# def states for nagios evaluation - we'll set these and evaluate later to see if we need to report an error
$nagRepadminState = 0
$nagBpaState = 0
$nagExitString = ""

# def CSV header
$Header = "showrepl_COLUMNS","Destination DSA Site","Destination DSA","Naming Context","Source DSA Site","Source DSA","Transport Type",`
            "Number of Failures","Last Failure Time","Last Success Time","Last Failure Status"

# create output path if it doesn't exist
if (!(test-path $outputPath)) { mkdir $outputPath }

# run repadmin create csv
Invoke-Expression $repCmd | Out-File "$outputPath/$outputFileRepadmin"

# get info from the csv
$repadminCsv = Import-Csv -Path "$outputPath/$outputFileRepadmin"

# parse repadmin statuses, store errors
if ($repadminStatus = $repadminCsv | Where-Object { $_.showrepl_COLUMNS -notmatch "showrepl_INFO" }) {
    $nagExitString += "Errors in repadmin results. See log at $outputPath\$outputFileRepadmin on "+(hostname)+". "
    $nagRepadminState = 2
} else {
    $nagExitString += "No errors found in repadmin results. "
}

# run best practices analyzer on directory services
Invoke-BpaModel -ModelId Microsoft/Windows/DirectoryServices
Get-BpaResult -ModelId Microsoft/Windows/DirectoryServices | ForEach Object {
    if ($_.severity -eq "Error") { 
        $_ | Out-File -Append -FilePath "$outputPath\$outputFileBpaStatus"
        if ($nagBpaState -lt 2) { $nagBpaState = 2; $nagExitString += "Best Practices Analyzer found errors. See log at $outputPath\$outputFileBpaStatus on "+(hostname)+". " }
    }
    elseif ($_.severity -eq "Warning") { 
        if ($nagBpaState -eq 0) { $nagBpaState = 1 }
    }
}

# if we didn't find errors above, update our exit string
if ($nagBpaState -eq 0) { $nagExitString += "No errors found in Best Practices Analyzer results. " }


write-host $nagExitString