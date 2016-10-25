#Destroy-NTNXVM.ps1
#   Copyright 2016 NetVoyage Corporation d/b/a NetDocuments.
param(
    [Parameter(mandatory=$true)][String]$VMName,
    [Parameter(mandatory=$false)][String]$DNSServer,
    [Parameter(mandatory=$false)][String]$DNSZone
)
#first check if the NutanixCmdletsPSSnapin is loaded, load it if its not, Stop script if it fails to load
if ( (Get-PSSnapin -Name NutanixCmdletsPSSnapin -ErrorAction SilentlyContinue) -eq $null ) {Add-PsSnapin NutanixCmdletsPSSnapin -ErrorAction Stop}
$connection = Get-NutanixCluster
#if not already connected to a cluster
if(!$connection.IsConnected){
    #prompt for inputs on the cluster/username/password to connect
    $NutanixCluster = (Read-Host "Nutanix Cluster")
    $NutanixClusterUsername = (Read-Host "Username for $NutanixCluster")
    $NutanixClusterPassword = (Read-Host "Password for $NutanixCluster" -AsSecureString)
    $connection = Connect-NutanixCluster -server $NutanixCluster -username $NutanixClusterUsername -password $NutanixClusterPassword -AcceptInvalidSSLCerts
    if ($connection.IsConnected){
        #connection success
        Write-Host "Connected to $($connection.server)" -ForegroundColor Green
    }
    else{
        #connection failure, stop script
        Write-Warning "Failed to connect to $NutanixCluster"
        Break
    }
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
    #if the DNSServer and DNSZone parameters are specified, try to remove the DNS entry
    if($DNSServer -and $DNSZone){
        try{
            Write-Host "Remove DNS record for $VMName, if exists"
            Remove-DnsServerResourceRecord -ComputerName $DNSServer -ZoneName $DNSZone -Name $VMName -Force -RRType A
        }
        catch {
            Write-Warning "Failed to remove $VMName from DNS, manual cleanup may be required"
        }
    }
}
else{
      Write-Host "$VMName does not exist on $($connection.server), exiting"
}
