#Create-NTNXVM.ps1
#   Copyright 2016 NetVoyage Corporation d/b/a NetDocuments.
param(
    [Parameter(mandatory=$true)][String]$VMName,
    [Parameter(mandatory=$true)][Int]$VMVLANID,
    [Parameter(mandatory=$true)][Int64]$VMRAMGB,
    [Parameter(mandatory=$false)][Int]$VMVcpus = 1, #default to 1
    [Parameter(mandatory=$false)][Int]$VMCoresPerVcpu = 1, #default to 1
    [Parameter(mandatory=$false)][String]$VMIP,
    [Parameter(ParameterSetName='Image')][Switch]$UseImageStore,
    [Parameter(ParameterSetName='Image')][String]$ImageName,
    [Parameter(ParameterSetName='CloneVM')][Switch]$CloneExistingVMDisk,
    [Parameter(ParameterSetName='CloneVM')][String]$ExistingVMName,
    [Parameter(ParameterSetName='BlankVM')][Switch]$UseBlankDisk,
    [Parameter(ParameterSetName='BlankVM')][Int]$DiskSizeGB = 20, #default to 20GB if not specified
    [Parameter(ParameterSetName='BlankVM')][Switch]$MountISO,
    [Parameter(ParameterSetName='BlankVM')][String]$ISOName,
    [Parameter(mandatory=$false)]$AdditionalVolumes, #pass an array of key:values
    [Parameter(mandatory=$false)][Switch]$noPowerOn,
    [Parameter(mandatory=$false)][String]$ClusterName,
    [Parameter(mandatory=$false)][String]$Description
)
#dot source Connect-Nutanix.ps1 and connect to the cluster
. .\lib\Connect-Nutanix.ps1
if ($ClusterName){ $connection = (Connect-Nutanix -ClusterName $ClusterName) }
else {
    $connection = (Connect-Nutanix)
    $ClusterName = (Get-NutanixCluster).server
}
if (!$connection){
    Write-Warning "Couldn't connect to a Nutanix Cluster"
    exit 1
}
#connection to cluster is all set up, now move on to the fun stuff
Write-Host "Checking if VM already exists..."
if (!(Get-NTNXVM -SearchString $VMName).vmid){
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
    #setup the VM's disk
    $vmDisk = New-NTNXObject -Name VMDiskDTO
    if($UseImageStore -and $ImageName){
        #setup the image to clone from the Image Store
        $diskCloneSpec = New-NTNXObject -Name VMDiskSpecCloneDTO
        #check to make sure specified Image exists in the Image Store
        $diskImage = (Get-NTNXImage | ?{$_.name -eq $ImageName})
        if($diskImage){
            if($diskImage.Length -gt 1){
                $diskToUse = $diskImage[0]
                foreach($disk in $diskImage){
                    if($disk.updatedTimeInUsecs -gt $diskToUse.updatedTimeInUsecs){ $diskToUse = $disk }
                }
                $diskImage = $diskToUse
            }
            $diskCloneSpec.vmDiskUuid = $diskImage.vmDiskId
        }
        else{
            Write-Warning "Specified Image Name: $ImageName, does not exist in the Image Store, exiting"
            Break
        }
        #setup the new disk from the Cloned Image
        $vmDisk.vmDiskClone = $diskCloneSpec
    }
    elseif($CloneExistingVMDisk -and $ExistingVMName){
        #setup the image to clone from the Existing VM
        $diskCloneSpec = New-NTNXObject -Name VMDiskSpecCloneDTO
        #check to make sure specified Existing VM Exists
        $diskToClone = ((Get-NTNXVMDisk -Vmid (Get-NTNXVM -searchstring $ExistingVMName).vmId) | ? {!$_.isCdrom})
        if($diskToClone){$diskCloneSpec.vmDiskUuid = $diskToClone.VmDiskUuid}
        else{
            Write-Warning "Specified Existing VM Name: $ExistingVMName, does not exist, exiting"
            Break
        }
        #setup the new disk from the Cloned Existing VM
        $vmDisk.vmDiskClone = $diskCloneSpec
    }
    elseif($UseBlankDisk){
        #setup the new disk on the default container
        $diskCreateSpec = New-NTNXObject -Name VmDiskSpecCreateDTO
        $diskCreateSpec.containerUuid = (Get-NTNXContainer).containerUuid
        $diskCreateSpec.sizeMb = $DiskSizeGB * 1024
        #create the Disk
        $vmDisk.vmDiskCreate = $diskCreateSpec
        if($AdditionalVolumes -or $MountISO){$vmDisk = @($vmDisk)}
        if($MountISO){
            #setup the ISO image to clone from the Image Store
            $diskCloneSpec = New-NTNXObject -Name VMDiskSpecCloneDTO
            #check to make sure specified ISO exists in the Image Store
            $ISOImage = (Get-NTNXImage | ?{$_.name -eq $ISOName})
            if($ISOImage){
                $diskCloneSpec.vmDiskUuid = $ISOImage.vmDiskId
                #setup the new ISO disk from the Cloned Image
                $vmISODisk = New-NTNXObject -Name VMDiskDTO
                #specify that this is a Cdrom
                $vmISODisk.isCdrom = $true
                $vmISODisk.vmDiskClone = $diskCloneSpec
                $vmDisk = @($vmDisk)
                $vmDisk += $vmISODisk
            }
            else{
                Write-Warning "Specified ISO Image Name: $ISOName, does not exist in the Image Store, skipping ISO mounting"
            }
        }
    }
    else{
        if($UseImageStore -and !$ImageName){
            Write-Warning "Must specify an ImageName when using -UseImageStore, exiting"
            Break
        }
        elseif($CloneExistingVM -and !$ExistingVMName){
            Write-Warning "Must specify an ExistingVMName to clone when using -CloneExistingVM, exiting"
            Break
        }
        else{
            Write-Warning "No source for $VMName's disk, must specify one of the following (UseImageStore, CloneExistingVM, UseBlankDisk), exiting"
            Break
        }
    }
    #adds any AdditionalVolumes if specified
    if($AdditionalVolumes){
        if(!($vmDisk[1])){$vmDisk = @($vmDisk)}
        foreach($volume in $AdditionalVolumes){
            $diskCreateSpec = New-NTNXObject -Name VmDiskSpecCreateDTO
            $diskCreateSpec.containerUuid = (Get-NTNXContainer).containerUuid
            $diskCreateSpec.sizeMb = $volume.Size * 1024
            $AdditionalvmDisk = New-NTNXObject -Name VMDiskDTO
            $AdditionalvmDisk.vmDiskCreate = $diskCreateSpec
            $vmDisk += $AdditionalvmDisk
        }
    }

    #Create the VM
    Write-Host "Creating $VMName on $ClusterName..."
    $createJobID = New-NTNXVirtualMachine -MemoryMb $ramMB -Name $VMName -NumVcpus $VMVcpus -NumCoresPerVcpu $VMCoresPerVcpu -VmNics $nicSpec -VmDisks $vmDisk -Description $Description -ErrorAction Continue
    if($createJobID){Write-Host "Created $VMName on $ClusterName" -ForegroundColor Green}
    else{
        Write-Warning "Couldn't create $VMName on $ClusterName, exiting"
        Break
    }
    #now wait for the VM to be created and then power it on, unless noPowerOn, then we are done
    if(!$noPowerOn){
        $count = 0
        #wait up to 30 seconds, trying every 5 seconds, for the vm to be created
        while (!$VMidToPowerOn -and $count -le 6){
            Write-Host "Waiting 5 seconds for $VMName to finish creating..."
            Start-Sleep 5
            $VMidToPowerOn = (Get-NTNXVM -SearchString $VMName).vmid
            $count++
        }
        #now power on the VM
        if ($VMidToPowerOn){
            Write-Host "Powering on $VMName on $ClusterName..."
            $poweronJobID = Set-NTNXVMPowerOn -Vmid $VMidToPowerOn
            if($poweronJobID){Write-Host "Successfully powered on $VMName on $ClusterName" -ForegroundColor Green}
            else{
                Write-Warning "Couldn't power on $VMName on $ClusterName, exiting"
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
    Write-Host "$VMName already exists on $ClusterName, exiting"
    Break
}
