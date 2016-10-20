#Create-NTNXVMFromImage.ps1
param(
    [Parameter(mandatory=$true)][String]$VMName,
    [Parameter(mandatory=$true)][Int]$VMVLANID,
    [Parameter(mandatory=$true)][Int64]$VMRAMGB,
    [Parameter(mandatory=$false)][Int]$VMVcpus = 1,
    [Parameter(mandatory=$false)][Int]$VMCoresPerVcpu = 1,
    [Parameter(mandatory=$false)][Int]$VMIP,
    [Parameter(mandatory=$true)][String]$NutanixImage,
    [Parameter(mandatory=$false)][Switch]$noPowerOn
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
    $connection = Connect-NutanixCluster -server $NutanixCluster -username $NutanixClusterUsername -password $NutanixClusterPassword –AcceptInvalidSSLCerts
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
#check if VM already exists
if (!(Get-NTNXVM -SearchString $VM.Name).vmid){
    #convert GB to MB for RAM
    $ramMB = ($VMRAMGB * 1024)
    #setup the nicSpec
    $nicSpec = New-NTNXObject -Name VMNicSpecDTO
    #find the right network to put the VM on
    $network = (Get-NTNXNetwork | ?{$_.vlanID -eq $VMVLANID})
    if($network){$nicSpec.networkuuid = $network.uuid}
    else{
        Write-Warning "Specified VLANID: $VMVLANID, does not exist, it needs to be created in Prism, exiting"
        Break
    }
    #request an IP, if specified
    if($VMIP){$nicSpec.requestedIpAddress = $VMIP}
    #setup the image to clone from the Image Store
    $diskCloneSpec = New-NTNXObject -Name VMDiskSpecCloneDTO
    #check to make sure specified Image exists in the Image Store
    $diskImage = (Get-NTNXImage | ?{$_.name -eq $NutanixImage})
    if($diskImage){$diskCloneSpec.vmDiskUuid = $diskImage.vmDiskId}
    else{
        Write-Warning "Specified Image: $NutanixImage, does not exist in the Image Store, exiting"
        Break
    }
    #setup the new disk from the Cloned Image
    $vmDisk = New-NTNXObject -Name VMDiskDTO
    $vmDisk.vmDiskClone = $diskCloneSpec
    #Create the VM
    Write-Host "Creating $VMName on $($connection.server)"
    $createJobID = New-NTNXVirtualMachine -MemoryMb $ramMB -Name $VM.Name -NumVcpus $VMVcpus -NumCoresPerVcpu $VMCoresPerVcpu -VmNics $nicSpec -VmDisks $vmDisk -ErrorAction Continue
    if($createJobID){Write-Host "Created $VMName on $($connection.server)" -ForegroundColor Green}
    else{
        Write-Warning "Couldn't create $VMName on $($connection.server), exiting"
        Break
    }
    #now wait for the VM to be created and then power it on, unless noPowerOn, then we are done
    if(!$noPowerOn){
        $count = 0
        #wait up to 30 seconds, trying every 5 seconds, for the vm to be created
        while ($VMidToPowerOn -eq $null -or $count -le 6){
            Write-Host "Waiting 5 seconds for $VMName to finish creating..."
            Start-Sleep 5
            $VMidToPowerOn = (Get-NTNXVM -SearchString $VMName).vmid
            $count++
        }
        #now power on the VM
        if ($VMidToPowerOn){
            Write-Host "Powering on $VMName on $($connection.server)..."
            $poweronJobID = Set-NTNXVMPowerOn -Vmid $VMidToPowerOn
            if($poweronJobID){Write-Host "Successfully powered on $VMName on $($connection.server)" -ForegroundColor Green}
            else{
                Write-Warning "Couldn't power on $VMName on $($connection.server), exiting"
                Break
            }
        }
        else {
            Write-Warning "Failed to Get $VMName after creation, not powering on..."
            Break
        }
    }
}
else{
    Write-Host "$($VM.Name) already exists on $($connection.server), exiting"
    Break
}
