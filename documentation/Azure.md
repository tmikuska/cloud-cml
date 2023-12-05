# Azure

Version 0.2.0, December 5 2023

This document explains specific configuration steps to deploy a CML instance in Azure.

## General requirements

The requirements for Azure are mostly identical with those for AWS. Please refer to the AWS document for instructions how to install Terraform. Azure needs the Azure CLI which can be downlaoded from [here](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli).

## Authentication

Once the Azure CLI (`az`) has been installed, it is required to log into Azure with an appropriate account.

> **Note:** It should also be possible to use a service principal with appropriate permissions. However, during the testing/development of the toolchain we did not have access to these resources.

The below shows sample output (`az` has been configured to provide output JSON encoded via `az configure`):

```
$ az login
A web browser has been opened at https://login.microsoftonline.com/organizations/oauth2/v2.0/authorize. Please continue the login in the web browser. If no web browser is available or if the web browser fails to open, use device code flow with `az login --use-device-code`.
[
  {
    "cloudName": "AzureCloud",
    "homeTenantId": "00000000-0000-4000-a000-000000000000",
    "id": "00000000-0000-4000-a000-000000000000",
    "isDefault": true,
    "managedByTenants": [],
    "name": "your-subscription-name",
    "state": "Enabled",
    "tenantId": "00000000-0000-4000-a000-000000000000",
    "user": {
      "name": "user@corp.com",
      "type": "user"
    }
  }
]
```

The provided subscription ID and the tenant ID need to be configured as Terraform variables. This can be done using environment variables and a shell script as hown here using `jq`:

```bash
#!/bin/bash

{ read subID ; read tenantID; } <<< "$(az account list --output=json | jq -r '.[0]|.id,.tenantId')"

export TF_VAR_tenant_id="$tenantID"
export TF_VAR_subscription_id="$subID"
```

## Software

CML software needs to be present on Azure in a storage account / blob container. See the AWS document where to download the .pkg file with the Debian packages. The layout of the files inside of the container is otherwise identical to the layout described in the AWS document:

```
"storage_account"
  - "container_name"
    - cml2_2.6.1-11_amd64.deb
    - refplat
    - node-definitions
        - iosv.yaml
        - ...
    - virl-base-images
        - iosv-159-3-m3
        - iosv-159-3-m3.yaml
        - vios-adventerprisek9-m-spa.159-3.m3.qcow2
        - ...
```

Where "storageaccountname" and "containername" are the names as configured in the `config.yml` file with the same attribute names.
