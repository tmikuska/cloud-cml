#!/bin/bash

#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2023, Cisco Systems, Inc.
# All rights reserved.
#

target="${cfg.target}"

function copyfile() {
	case $target in
		aws)
			loc='${cfg.aws.bucket}'
			aws s3 cp --no-progress $3 "s3://$loc/$1" $2
			;;
		azure)
			loc='${cfg.azure.storage_location}'
			azcopy copy --output-level=quiet "$loc/$1$SAS_TOKEN" $2 $3
			;;
		*)
			;;
	esac
}

