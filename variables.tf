#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2023, Cisco Systems, Inc.
# All rights reserved.
#

# AWS related vars

variable "cfg_file" {
  type        = string
  description = "Name of the YAML config file to use"
  default     = "config.yml"
}

variable "aws_access_key" {
  type        = string
  description = "AWS access key / credential for the provisioning user"
  default     = "notset"
}

variable "aws_secret_key" {
  type        = string
  description = "AWS secret key matching the access key"
  default     = "notset"
}

# Azure related vars

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
  default     = "notset"
}

variable "tenant_id" {
  type        = string
  description = "Azure tenant ID"
  default     = "notset"
}
