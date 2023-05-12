# Import-Module ../arm-template-toolkit/arm-ttk/arm-ttk.psd1

param(
    [Parameter()]
    [String]$env,
    [String]$client,
    [String]$subscriptionId,
    [String]$location
)

# Connect-AzAccount
 
# $env = 'dev'
# $client = 'www'
# $subscriptionId = "a4e31a79-1b22-4591-b289-2dd5e2769c08"
# $location = "westeurope" # Is used only for new deployment. If Resouce group already exists, location will not get changed.

# select subscription
Write-Host "Selecting subscription '$subscriptionId'"
# Set-AzContext -SubscriptionId  $subscriptionId

function Get-ResourceGroupName {

    param (
        $env,
        $client,
        $resource
    )
    $resourceGroupName = "wade-{0}-{1}-rg-{2}" -f $client, $resource, $env

    Write-Output $resourceGroupName
}

function Remove-ResourceGroup {
    param (
        $env,
        $client,
        $resource
    )
    $resourceGroupName = Get-ResourceGroupName -env $env -client $client -resource $resource
    # Write-Host $resourceGroupName
    # Get-AzResourceGroup -Name $resourceGroupName | Remove-AzResourceGroup -Force
    try {
        Remove-AzResourceGroup -Name $resourceGroupName -Force -ErrorAction Stop
        Write-Host "$resourceGroupName Resource Group was successfully deleted."    
    }
    catch {
        $message = $_
        Write-Host "$resourceGroupName does not exist or other error arised during deletion."
        Write-Warning $message
    }
    
}
function Deploy-ResourceGroup {
    param (
        $env,
        $client,
        $resource,
        $location,
        $templateFile,
        $templateParameterFile,
        $adminGroupId
    )
    $resourceGroupName = Get-ResourceGroupName -env $env -client $client -resource $resource
    Write-Host $resourceGroupName
    Get-AzResourceGroup -Name $resourceGroupName -ErrorVariable notPresent -ErrorAction SilentlyContinue

    #Create or check for existing resource group
    if ($notPresent) {
        Write-Host "Resource group $resourceGroupName does not exist. Creating it."
        New-AzResourceGroup -Name $resourceGroupName -Location $location
        # $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    }
    Write-Host "Using resource group: $resourceGroupName"    

    # Test templates
    # Test-AzTemplate -TemplatePath $templateFile

    $deploymentName = Get-Date -Format "yyyyMMddhhmm"
    # Start the deployment
    try {
        if ($resource -eq 'synw') {
            New-AzResourceGroupDeployment `
                -client $client `
                -environment $env `
                -location $location `
                -adminObjectId $adminGroupId `
                -ResourceGroupName $resourceGroupName `
                -Name $deploymentName `
                -TemplateFile $templateFile `
                -TemplateParameterFile $templateParameterFile `
                -ErrorAction Stop 
        }
        else {
            New-AzResourceGroupDeployment `
                -client $client `
                -environment $env `
                -location $location `
                -ResourceGroupName $resourceGroupName `
                -Name $deploymentName `
                -TemplateFile $templateFile `
                -TemplateParameterFile $templateParameterFile `
                -ErrorAction Stop        <# Action when all if and elseif conditions are false #>
        }


        Write-Host "$resourceGroupName Resource Group was successfully deployed."        
    }
    catch {
        $message = $_
        Write-Host "Failed to create resouce group $resourceGroupName" 
        Write-Warning $message

        Write-Error -Message "Houston, we have a problem." -ErrorAction Stop
    }

}

function Deploy-All {
    param (
        $env,
        $client,
        $location,
        $adminGroupId
    )
    # $resourceGroupName = Get-ResourceGroupName -env $env -client $client -resource 'dbw'
    # Write-Host $resourceGroupName

    $predefined_envs = 'dev', 'test', 'prod'
    if ($predefined_envs -contains $env)
    {
        $env_path = $env
    }
    else
    {
        $env_path = 'dev'
    }

    # Deploy Databricks
    Deploy-ResourceGroup -env $env -client $client -resource 'dbw' -location $location -templateFile 'arm/databricks_template.json' -templateParameterFile "params/$env_path/databricks_parameters.json"
    # Deploy Lake
    Deploy-ResourceGroup -env $env -client $client -resource 'storage' -location $location -templateFile 'arm/datalake_template.json' -templateParameterFile "params/$env_path/datalake_parameters.json"
    # Deploy Function
    Deploy-ResourceGroup -env $env -client $client -resource 'functions' -location $location -templateFile 'arm/functions_template.json' -templateParameterFile "params/$env_path/functions_parameters.json"
    # Deploy KeyVault
    Deploy-ResourceGroup -env $env -client $client -resource 'common' -location $location -templateFile 'arm/keyvault_template.json' -templateParameterFile "params/$env_path/keyvault_parameters.json"
    # Deploy Synapse
    Deploy-ResourceGroup -env $env -client $client -resource 'synw' -location $location -adminGroupId $adminGroupId -templateFile 'arm/synapse_template.json' -templateParameterFile "params/$env_path/synapse_parameters.json"    

}

function Remove-All {
    param (
        $env,
        $client
    )

    Remove-AzResourceGroup -Name "NetworkWatcherRG" -Force -ErrorAction SilentlyContinue
    Remove-ResourceGroup -env $env -client $client -resource 'dbw'
    Remove-ResourceGroup -env $env -client $client -resource 'storage'
    Remove-ResourceGroup -env $env -client $client -resource 'functions'
    Remove-ResourceGroup -env $env -client $client -resource 'common'
    Remove-ResourceGroup -env $env -client $client -resource 'synw'
    
}

# Create Synapse Admins Group
$groupName = "$client-synapse-admins"

# $group = Get-AzADGroup -DisplayName $groupName # TODO -> add back in
$group = 'Temp' # TODO -> detele

if ($group -eq $null) {
    Write-Host "Group does not exist"
    # $group = az ad group create --display-name $groupName --mail-nickname $groupName | ConvertFrom-Json 
    # $groupId = $group.objectId 
    Write-Error -Message "Create an Azure Group $groupName to continue..." -ErrorAction Stop
}
else {
    Write-Host "Group exists"
    # $groupId = $group.Id # TODO add back in
    $groupId = '647303b1-abd7-4890-b296-2e4a7fc4a3a8' # TODO -> delete; temp solution before getting Read Permissions in AAD
}


Write-Host "Group ID >>>>> $groupId"

# Remove-All -client $client -env $env
Deploy-All -client $client -env $env -location $location -adminGroupId $groupId

# RBAC

# Grant Synapse Workspace Storage Blob Data Contributor in the lake
$storageRgName = Get-ResourceGroupName -env $env -client $client -resource 'storage'
$synapseRgName = Get-ResourceGroupName -env $env -client $client -resource 'synw'
$synapseWorkspaceName = "wade-$client-analytics-synw-$env"

$s = az synapse workspace show --name $synapseWorkspaceName --resource-group $synapseRgName 
$js = $s | ConvertFrom-Json 
$assignee = $js.identity.principalId
az role assignment create --assignee $assignee --role "Storage Blob Data Contributor" --resource-group $storageRgName


