#Connect-Nutanix.ps1
function Connect-Nutanix {
    param(
        [parameter(mandatory=$false)]$ClusterName
    )
    #first check if the NutanixCmdletsPSSnapin is loaded, load it if its not, Stop script if it fails to load
    if ( (Get-PSSnapin -Name NutanixCmdletsPSSnapin -ErrorAction SilentlyContinue) -eq $null ) {Add-PsSnapin NutanixCmdletsPSSnapin -ErrorAction Stop}
    $connection = Get-NutanixCluster
    #if not connected to a cluster or the connection is older than 1 hour, then connect/reconnect
    if(!$connection.IsConnected -or ([datetime]$connection.lastAccessTimestamp -lt (Get-Date).AddHours(-1))){
        if ($connection.IsConnected) { Disconnect-NTNXCluster $connection.server }
        #if not already connected to a cluster, prompt for inputs on the cluster/username/password to connect
        #if the ClusterName Parameter is passed, connect to that cluster, otherwise prompt for the clustername
        if($ClusterName){$NutanixCluster = $ClusterName}
        else{$NutanixCluster = (Read-Host "Nutanix Cluster")}
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
    else{
        #make sure we're connected to the right cluster
        if($ClusterName -and ($ClusterName -ne $($connection.server))){
            #we're connected to the wrong cluster, reconnect to the right one
            Disconnect-NTNXCluster $connection.server
            $connection = Get-NutanixCluster
            $NutanixCluster = $ClusterName
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
    }
    return [bool]$connection.IsConnected
}
