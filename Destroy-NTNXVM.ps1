#Destroy-NTNXVM.ps1
#   Copyright 2016 NetVoyage Corporation d/b/a NetDocuments.
param(
    [Parameter(mandatory=$true)][String]$VMName,
    [Parameter(mandatory=$false)][String]$ClusterName
)
#dot source Connect-Nutanix.ps1 and connect to the cluster
. .\Connect-Nutanix.ps1
if ($ClusterName){ $connection = (Connect-Nutanix -ClusterName $ClusterName) }
else { $connection = (Connect-Nutanix) }
if (!$connection){
    Write-Warning "Couldn't connect to a Nutanix Cluster"
    exit 1
}
#connection to cluster is all set up, now move on to the fun stuff
#check to make sure VM exists on the cluster
$VM = (Get-NTNXVM -SearchString $VMName)
if ($VM.vmid){
    Write-Host "Removing $VMName from $($connection.server)"
    $removeVMJobID = Remove-NTNXVirtualMachine -vmid $VM.vmid
    #make sure the job to remove the VM got submitted
    if($removeVMJobID){Write-Host "Successfully removed $VMName from $($connection.server)" -ForegroundColor Green}
    else{
        Write-Warning "Failed to remove $VMName from $($connection.server), exiting"
        Break
    }
}
else{
      Write-Host "$VMName does not exist on $($connection.server), exiting"
}
