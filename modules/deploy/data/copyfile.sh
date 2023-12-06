#!/bin/bash

#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2023, Cisco Systems, Inc.
# All rights reserved.
#

TARGET="${cfg.target}"

function copyfile() {
	SRC=$1
	DST=$2
	RECURSIVE=$3
	case $TARGET in
		aws)
			LOC='${cfg.aws.bucket}'
			aws s3 cp --no-progress $RECURSIVE "s3://$LOC/$SRC" $DST
			;;
		azure)
			# SAS_TOKEN must be exported to permit access
			LOC="https://${cfg.azure.storage_account}.blob.core.windows.net/${cfg.azure.container_name}"
			azcopy copy --output-level=quiet "$LOC/$SRC$SAS_TOKEN" $DST $RECURSIVE
			;;
		*)
			;;
	esac
}

