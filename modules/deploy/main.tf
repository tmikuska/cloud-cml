#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2023, Cisco Systems, Inc.
# All rights reserved.
#

provider "aws" {
  secret_key = var.aws_secret_key
  access_key = var.aws_access_key
  region     = var.cfg.aws.region
}

provider "azurerm" {
  features {}

  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id

  # Configuration options
}

module "aws" {
  source = "./aws"
  count  = var.cfg.target == "aws" ? 1 : 0
  cfg    = var.cfg
}

module "azure" {
  source = "./azure"
  count  = var.cfg.target == "azure" ? 1 : 0
  cfg    = var.cfg
}

