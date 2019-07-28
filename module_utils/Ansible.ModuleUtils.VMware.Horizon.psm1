# Copyright (c) 2019 sky-joker
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

Function Get-HVServices {
    Param(
        $module
    )

    $hostname = $module.Params.hostname
    $username = $module.Params.username
    $password = $module.Params.password
    $domain = $module.Params.domain
    $validate_certs = $module.Params.validate_certs

    try {
        if ($validate_certs) {
            $hvServer = Connect-HVServer -Server $hostname -User $username -Password $password -Domain $domain
        } else {
            $hvServer = Connect-HVServer -Server $hostname -User $username -Password $password -Domain $domain -Force
        }
    } catch {
        $module.FailJson("$($_.Exception.Message)", $_)
    }

    $services = $hvServer.ExtensionData

    return $services
}

Function Get-HorizonQuery {
    Param(
        [Parameter(Mandatory=$true)]$module,
        [Parameter(Mandatory=$true)]$services,
        [Parameter(Mandatory=$true)]$query_entity_type,
        $query_filter
    )

    $queryService = New-Object VMWare.Hv.QueryServiceService
    $query = New-Object VMware.Hv.QueryDefinition
    $query.queryEntityType = $query_entity_type

    if($query_filter) {
        $query.filter = $query_filter
    }

    try {
        $queryResults = $queryService.QueryService_Create($services, $query)
    } catch {
        $module.FailJson("$($_.Exception.Message)", $_)
    }

    $queryService.QueryService_Delete($services, $queryResults.Id)

    return ,$queryResults.Results
}

#Function Get-HorizonDesktopPool {
#    Param(
#        $module,
#        $services,
#        $query_filter
#    )
#
#    $queryResult = Get-HorizonQuery $module $services "DesktopSummaryView" $query_filter
#
#    return ,$queryResult.Results
#}

Function Get-HorizonVMFromVirtualCenter {
    Param(
        [Parameter(Mandatory=$true)]$services,
        [Parameter(Mandatory=$true)][String]$vcenter_name,
        [Parameter(Mandatory=$true)][String]$name
    )

    $vms = @()
    try {
        $vcs = $services.VirtualCenter.VirtualCenter_List()
    } catch {
        $module.FailJson("$($_.Exception.Message)", $_)
    }

    foreach ($vc in $vcs) {
        if ($vc.ServerSpec.ServerName -eq $vcenter_name) {
            $vms = $services.VirtualMachine.VirtualMachine_List($vc.Id)
            break
        }
    }

    if($vms) {
        foreach($vm in $vms) {
            if($vm.Name -eq $name) {
                $vm_obj = $vm
            }
        }
    }

    return ,$vm_obj
}

