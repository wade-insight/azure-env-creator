param (
    $env,
    $client, 
    $subscriptionId,
    $location
    )

if ($env -eq $null) {
    $env = read-host -Prompt "Please enter an environemnt type (dev, test, prod)"
} 
if ($client -eq $null) {
    $client = read-host -Prompt "Please enter your wade idenitity"
}
if ($subscriptionId -eq $null) {
    $subscriptionId = read-host -Prompt "Please enter your Azure subscription id"
}
if ($location -eq $null) {
    $location = read-host -Prompt "Please enter Azure Region you want to deploy to (westeurope, northeurope, etc.)"
}

Connect-AzAccount
# Select subscription
Write-Host "Selecting subscription '$subscriptionId'"
Set-AzContext -SubscriptionId  $subscriptionId

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
        $adminObjectId,
        $templateFile,
        $templateParameterFile
    )
    $resourceGroupName = Get-ResourceGroupName -env $env -client $client -resource $resource
    # Write-Host $resourceGroupName
    $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorVariable notPresent -ErrorAction SilentlyContinue

    #Create or check for existing resource group
    if ($notPresent) {
        Write-Host "Resource group $resourceGroupName does not exist. Creating it."
        New-AzResourceGroup -Name $resourceGroupName -Location $location
        $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    }
    Write-Host "Using resource group: $resourceGroupName"    

    # Test templates
    # Test-AzTemplate -TemplatePath $templateFile

    $deploymentName = Get-Date -Format "yyyyMMddhhmm"
    # Start the deployment
    try {
        $adminObjectId = (Get-AzContext).Account.ExtendedProperties.HomeAccountId.Split('.')[0]
        if ($resource -eq 'synw')
            {
                New-AzResourceGroupDeployment `
                -client $client `
                -environment $env `
                -location $location `
                -ResourceGroupName $resourceGroupName `
                -Name $deploymentName `
                -TemplateFile $templateFile `
                -TemplateParameterFile $templateParameterFile `
                -adminObjectId $adminObjectId `
                -ErrorAction Stop
            }
        else
            {
                New-AzResourceGroupDeployment `
                -client $client `
                -environment $env `
                -location $location `
                -ResourceGroupName $resourceGroupName `
                -Name $deploymentName `
                -TemplateFile $templateFile `
                -TemplateParameterFile $templateParameterFile `
                -ErrorAction Stop
            }

        Write-Host "$resourceGroupName Resource Group was successfully deployed."        
    }
    catch {
        $message = $_
        Write-Host "Failed to create resouce group $resourceGroupName" 
        Write-Warning $message
    }

}

function Deploy-All {
    param (
        $env,
        $client,
        $location
    )
    Write-Host("Deploying WADE in $subscriptionId for $client, $env environment")
    

    # Deploy Databricks
    # Deploy-ResourceGroup -env $env -client $client -resource 'dbw' -location $location -templateFile 'arm/databricks_template.json' -templateParameterFile "params/databricks_parameters.json"

    # Deploy Lake
    # Deploy-ResourceGroup -env $env -client $client -resource 'storage' -location $location -templateFile 'arm/datalake_template.json' -templateParameterFile "params/datalake_parameters.json"

    # Deploy Function
    # Deploy-ResourceGroup -env $env -client $client -resource 'functions' -location $location -templateFile 'arm/functions_template.json' -templateParameterFile "params/functions_parameters.json"

    # Deploy KeyVault
    # Deploy-ResourceGroup -env $env -client $client -resource 'common' -location $location -templateFile 'arm/keyvault_template.json' -templateParameterFile "params/keyvault_parameters.json"

    # Deploy Synapse
    Deploy-ResourceGroup -env $env -client $client -resource 'synw' -location $location -templateFile 'arm/synapse_template.json' -templateParameterFile "params/synapse_parameters.json"    

}

function Remove-All {
    param (
        $env,
        $client
    )
    Write-Host("Removing all resources for $client in $env")
    Remove-AzResourceGroup -Name "NetworkWatcherRG" -Force -ErrorAction SilentlyContinue
    Remove-ResourceGroup -env $env -client $client -resource 'dbw'
    Remove-ResourceGroup -env $env -client $client -resource 'storage'
    Remove-ResourceGroup -env $env -client $client -resource 'functions'
    Remove-ResourceGroup -env $env -client $client -resource 'common'
    Remove-ResourceGroup -env $env -client $client -resource 'synw'
    
}

# Remove-All -client $client -env $env

Deploy-All -client $client -env $env -location $location
