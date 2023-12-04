#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2023, Cisco Systems, Inc.
# All rights reserved.
#

output "public_ip" {
  value = (
	(var.cfg.target == "aws") ? 
	  module.aws[0].public_ip :
	(var.cfg.target == "azure" ?
	  module.azure[0].public_ip :
	  "no ip"
	)
  )
}
