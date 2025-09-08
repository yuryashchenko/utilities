
# Azure Subnet Address Space Extension

This script, `azureSubnetAddressSpaceExtension.ps1`, demonstrates and tests the Azure Subnet Address Space Extension feature, now production-ready for Azure customers. It automates the creation of resources, configures peering, sets up private endpoints, and extends subnet address spaces to validate feature limitations and behavior.

## What the Script Does

1. **Connects to Azure** using a specified tenant ID.
2. **Creates a resource group and two virtual networks** (`myVNet1` and `myVNet2`) in the same region, each with two subnets.
3. **Configures VNet peering** between the two virtual networks for bidirectional connectivity.
4. **Enables service endpoints** (Microsoft.Storage, Microsoft.Sql) for selected subnets.
5. **Creates two storage accounts** and sets up private endpoints in each VNet/subnet.
6. **Extends the address space** for `mySubnet1` and `mySubnet3` by adding new address prefixes, testing the Azure Subnet Address Space Extension capability.

## Prerequisites

- Azure PowerShell module (`Az`) installed
- Sufficient permissions to create and manage resource groups, VNets, subnets, storage accounts, and private endpoints
- Logged in to your Azure account (`Connect-AzAccount`)

## Usage

1. Update the script with your Azure tenant ID and desired resource names if needed.
2. Open PowerShell and navigate to the script directory:
   ```powershell
   cd Azure/SubnetExtension
   ```
3. Run the script:
   ```powershell
   .\azureSubnetAddressSpaceExtension.ps1
   ```

## Limitations and Scenarios Tested

- Extending subnet address space with additional prefixes
- Service endpoint configuration compatibility
- Private endpoint connectivity after address space extension
- VNet peering behavior with extended subnets
- Resource creation and update constraints

## Output

- Resource creation logs
- Subnet address space extension results
- Any errors or limitations encountered during the process

## Notes

- The script is intended for testing and validation. Review and update parameters for your environment before running.
- Running this script will create and modify Azure resources; charges may apply.

## References

- [Azure Subnet Address Space Extension Documentation](https://learn.microsoft.com/en-us/azure/virtual-network/how-to-multiple-prefixes-subnet?tabs=powershell)
- [Azure PowerShell Documentation](https://learn.microsoft.com/en-us/powershell/azure/new-azureps-module-az)
