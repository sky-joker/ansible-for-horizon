#!powershell

# Copyright: (c) 2019, sky-joker
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.VMware.Horizon
#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        hostname = @{ type = "str"; required = $true; }
        username = @{ type = "str"; required = $true; }
        password = @{ type = "str"; no_log = $true; required = $true; }
        domain = @{ type = "str"; required = $true; }
        validate_certs = @{ type = "bool"; default = $true; }
        vcenter_server = @{ type = "str"; required = $true; }
        desktop_pool = @{ type = "str"; required = $true; }
        name = @{ type = "str"; required = $true; }
        state = @{ type = "str"; default = "present"; choices = @("present", "absent"); }
    }
    supports_check_mode = $false
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$vcenter_server = $module.Params.vcenter_server
$desktop_pool = $module.Params.desktop_pool
$name = $module.Params.name
$state = $module.Params.state

$services = Get-HVServices $module

# Get desktop pool id.
$query_filter = New-Object VMware.Hv.QueryFilterEquals
$query_filter.memberName = "desktopSummaryData.displayName"
$query_filter.value = $desktop_pool
$queryResults = Get-HorizonQuery $module $services "DesktopSummaryView" $query_filter
if ($queryResults) {
    $desktop_pool_id = $queryResults[0].Id
} else {
    $module.FailJson("Desktop Pool $desktop_pool not found")
}

# Get vm in desktop pool.
$query_filter = New-Object VMware.Hv.QueryFilterEquals
$query_filter.memberName = "base.desktop"
$query_filter.value = $desktop_pool_id
$queryResults = Get-HorizonQuery $module $services "MachineSummaryView" $query_filter
if($queryResults) {
    $desktop_pool_vms = $queryResults
}

# Check if VM exist in pool.
if($desktop_pool_vms) {
    foreach($vm in $desktop_pool_vms) {
        if($vm.Base.Name -eq $name) {
            $exist_vm = $vm
            break
        }
    }
}

$module.Result.changed = $false
if($state -eq "present") {
    if(!$exist_vm) {
        $vm_obj = Get-HorizonVMFromVirtualCenter $services $vcenter_server $name
        if($vm_obj) {
            try {
                $services.Desktop.Desktop_AddMachineToManualDesktop($desktop_pool_id, $vm_obj.Id)
            } catch {
                $module.FailJson("$( $_.Exception.Message )", $_)
            }
            $module.Result.changed = $true
        } else {
            $module.FailJson("VM $name not found")
        }
    }
}

if($state -eq "absent") {
    if($exist_vm) {
        try {
            $services.Desktop.Desktop_RemoveMachineFromManualDesktop($desktop_pool_id, $exist_vm.Id)
        } catch {
            $module.FailJson("$( $_.Exception.Message )", $_)
        }
        $module.Result.changed = $true
    }
}

$module.ExitJson()
