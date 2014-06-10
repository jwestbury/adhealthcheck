if((Get-EventLog -LogName 'DFS Replication')[0].EventID -eq 2213) {
    write-host "DFS Replication failed and requires manual intervention. See event log."
    exit 2
} elseif((Get-EventLog -LogName 'DFS Replication')[0].EntryType -eq "Error") {
    write-host "DFS Replication errors present. See event log."
    exit 2
} elseif((Get-EventLog -LogName 'DFS Replication')[0].EntryType -ne "Information") {
    write-host "DFS Replication warnings present. See event log."
    exit 1
} else {
    write-host "DFS Replication is okay."
    exit 0
}