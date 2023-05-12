# Azure Environment Creator

This GitHub repository contains code for creating a new WADE environment in Azure for a new customer. The repository includes a PowerShell script called `manual-deploy.ps1` that allows you to manually deploy the Azure resources and services required for the customer's environment.

## Prerequisites

Before using the `manual-deploy.ps1` script, make sure you have the following prerequisites:

- An Azure subscription with Owner permissions 
- Following Resource Providers are enabled in the subsciptions where WADE environment will be installed:
  - Databricks
  - SQL
  - Synapse
- Azure PowerShell module installed on your local machine. You can install the Azure PowerShell module using the following command in PowerShell:

  ```
  Install-Module -Name Az
  ```

## Usage

To use the `manual-deploy.ps1` script, follow these steps:

1. Open a PowerShell console on your local machine.
2. Navigate to the directory where you cloned the `azure-env-creator` repository.
3. Run the `manual-deploy.ps1` script and fill in the following parameters:

   - `Environment Type`: environemnt type (e.g. dev, test, prod)
   - `Wade Identity`: is provided to you when you register yourslef at WADE, should be saved in Key Vault as azure-identity.
   - `Azure Subscription ID`: The ID of your Azure Subscripiton.
   - `Azure Region`: Azure Region you want to deploy into.
   
4. Wait for the script to complete. This may take several minutes, depending on the resources being provisioned.
