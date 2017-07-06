# nutanix-powershell
Series of Powershell Scripts for interacting with Nutanix Clusters
### Examples:
Example 1: Create a VM with 4GB of RAM, 2 Vcpus with 2 cores each and clone the disk from the Image Store using the Image Named win2012.
````Powershell
.\Create-NTNXVM.ps1 -VMName "test01" -VMVLANID 1 -VMRAMGB 4 -VMVcpus 2 -VMCoresPerVcpu 2 -VMIP "10.1.1.180" -UseImageStore -ImageName "win2012"
````
Example 2: Create a VM with 2GB of RAM, 1 Vcpu (default) with 4 cores and clone the disk from the existing VM called "test01", don't power the VM on after creating it (will need to power it manually from Prism).
````Powershell
.\Create-NTNXVM.ps1 -VMName "test02" -VMVLANID 1 -VMRAMGB 2 -VMCoresPerVcpu 4 -VMIP "10.1.1.180" -CloneExistingVM -ExistingVMName "test01" -noPowerOn
````
Example 3: Create a VM with 2GB of RAM, 2 Vcpus (they will get 1 core each by default) and create a new blank 100GB disk. Also, don't specify an IP address for this VM (it will need to get a static IP later).
````Powershell
.\Create-NTNXVM.ps1 -VMName "test03" -VMVLANID 1 -VMRAMGB 2 -VMVcpus 2 -UseBlankDisk -DiskSizeGB 100
````
Example 4: Create a VM with 4GB of RAM and 8 cores (all 8 cores will be on 1 Vcpu) and create a new blank 50GB disk, mount the ISO from the image store called "Windows Server 2012 R2", the VM will then boot from the ISO.
````Powershell
.\Create-NTNXVM.ps1 -VMName "test04" -VMVLANID 1 -VMRAMGB 4 -VMCoresPerVcpu 8 -VMIP "10.1.1.180" -UseBlankDisk -DiskSizeGB 50 -MountISO -ISOName "Windows Server 2012 R2"
````
Throw all the "test" VMs away.
````Powershell
.\Destroy-NTNXVM.ps1 -VMName "test01"
.\Destroy-NTNXVM.ps1 -VMName "test02"
.\Destroy-NTNXVM.ps1 -VMName "test03"
.\Destroy-NTNXVM.ps1 -VMName "test04"
````
Copyright 2017 NetDocuments Ltd.
