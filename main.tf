#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2023, Cisco Systems, Inc.
# All rights reserved.
#

locals {
  cfg_file = file("config.yml")
  cfg      = yamldecode(local.cfg_file)
}

module "deploy" {
  source = "./modules/deploy"
  cfg    = local.cfg
}

provider "cml2" {
  address        = "https://${module.deploy.public_ip}"
  username       = local.cfg.app.user
  password       = local.cfg.app.pass
  use_cache      = false
  skip_verify    = true
  dynamic_config = true
}

module "ready" {
  source = "./modules/readyness"
  depends_on = [
    module.deploy.public_ip
  ]
}
