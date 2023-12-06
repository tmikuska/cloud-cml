#!/bin/bash

#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2023, Cisco Systems, Inc.
# All rights reserved.
#

# NOTE: vars with dollar curly brace are HCL template vars, getting replaced
# by Terraform with actual values before the script is deployed to the VM!
#
# If a dollar curly brace is needed in the shell script itself, it needs to be
# written with two dollar signs and a pair of double curly braces.

set -x
# set -e

source /provision/copyfile.sh

function setup_pre_aws() {
	export AWS_DEFAULT_REGION='${cfg.aws.region}'
	apt-get install -y awscli
}

function setup_pre_azure() {
    export SAS_TOKEN='${cfg.sas_token}'
    curl -LO https://aka.ms/downloadazcopy-v10-linux
    tar xvf down* --strip-components=1 -C /usr/local/bin
    chmod a+x /usr/local/bin/azcopy
}


function base_setup() {
    # copy Debian package from cloud storage into our instance
	copyfile '${cfg.app.deb}' /provision/

    # copy node definitions and images to the instance
    VLLI=/var/lib/libvirt/images
    NDEF=node-definitions
    IDEF=virl-base-images
    mkdir -p $VLLI/$NDEF

    # copy all node definitions as defined in the provisioned config
    if [ $(jq </provision/refplat '.definitions|length') -gt 0 ]; then
        elems=$(jq </provision/refplat -rc '.definitions|join(" ")')
        for item in $elems; do
            copyfile refplat/$NDEF/$item.yaml $VLLI/$NDEF/
        done
    fi

    # copy all image definitions as defined in the provisioned config
    if [ $(jq </provision/refplat '.images|length') -gt 0 ]; then
        elems=$(jq </provision/refplat -rc '.images|join(" ")')
        for item in $elems; do
            mkdir -p $VLLI/$IDEF/$item
            copyfile refplat/$IDEF/$item/ $VLLI/$IDEF/ --recursive
        done
    fi

    # if there's no images at this point, copy what's available in the defined
	# cloud storage container
    if [ $(find $VLLI -type f | wc -l) -eq 0 ]; then
        copyfile refplat/ $VLLI/ --recursive
    fi

    systemctl stop ssh
    apt-get install -y '/provision/${cfg.app.deb}'
    systemctl start ssh

    FILELIST=$(find /provision/ -type f -name '*.sh' | grep -v '99-dummy.sh')
    if [ -n "$FILELIST" ]; then
		systemctl stop virl2.target
        while [ $(systemctl is-active virl2-controller.service) = active ]; do
            sleep 5
        done
        (
			mkdir -p /var/log/provision
            echo "$FILELIST" | sort |
            while read patch; do
				(
					source "$patch"
				) 2>&1 | tee "/var/log/"$patch".log"
            done
        )
        sleep 5
        systemctl restart virl2.target
    fi

	# AWS specific (?):
    # For troubleshooting. To allow console access on AWS, the root user needs a
    # password. Note: not all instance types / flavors provide a serial console!
    # echo "root:secret-password-here" | /usr/sbin/chpasswd
}

function cml_configure() {
	target=$1
    API="http://ip6-localhost:8001/api/v0"

    # Create system user
    /usr/sbin/useradd --badname -m -s /bin/bash '${cfg.sys.user}'
    echo '${cfg.sys.user}:${cfg.sys.pass}' | /usr/sbin/chpasswd
    /usr/sbin/usermod -a -G sudo '${cfg.sys.user}'

	# Move SSH config from default cloud-provisioned user to new user. This
	# also disables the login for this user by removing the SSH key.
	# Technically, this could be the same user as Azure allows to set the
	# user name
	# if [ "$target" = "aws" ]; then
	# 	clouduser="ubuntu"
	# elif [ "$target" = "azure" ]; then
	# 	clouduser="adminuser"
	# else
	# 	echo "unknown target"
	# fi
	clouduser="ubuntu"
    mv /home/$clouduser/.ssh '/home/${cfg.sys.user}/'
    chown -R '${cfg.sys.user}.${cfg.sys.user}' '/home/${cfg.sys.user}/.ssh'

    # Change the ownership of the del.sh script to the sysadmin user
    chown '${cfg.sys.user}.${cfg.sys.user}' /provision/del.sh

    until [ "true" = "$(curl -s $API/system_information | jq -r .ready)" ]; do
        echo "Waiting for controller to be ready..."
        sleep 5
    done

    # Get auth token
    PASS=$(cat /etc/machine-id)
    TOKEN=$(echo '{"username":"cml2","password":"'$PASS'"}' \ |
        curl -s -d@- $API/authenticate | jq -r)
    [ "$TOKEN" != "Authentication failed!" ] || { echo $TOKEN; exit 1; }

    # Change to provided name and password
    curl -s -X "PATCH" \
        "$API/users/00000000-0000-4000-a000-000000000000" \
        -H "Authorization: Bearer $TOKEN" \
        -H "accept: application/json" \
        -H "Content-Type: application/json" \
        -d '{"username":"${cfg.app.user}","password":{"new_password":"${cfg.app.pass}","old_password":"'$PASS'"}}'

    # Re-auth with new password
    TOKEN=$(echo '{"username":"${cfg.app.user}","password":"${cfg.app.pass}"}' \ |
        curl -s -d@- $API/authenticate | jq -r)

    # This is still local, everything below talks to GCH licensing servers
    curl -s -X "PUT" \
        "$API/licensing/product_license" \
        -H "Authorization: Bearer $TOKEN" \
        -H "accept: application/json" \
        -H "Content-Type: application/json" \
        -d \"'${cfg.license.flavor}'\"

    # We want to see what happens
    set -x

    # Licensing steps
    curl -vs -X "POST" \
        "$API/licensing/registration" \
        -H "Authorization: Bearer $TOKEN" \
        -H "accept: application/json" \
        -H "Content-Type: application/json" \
        -d '{"token":"${cfg.license.token}","reregister":false}'

    # No need to put in node licenses - unavailable
    if [[ ${cfg.license.flavor} =~ ^CML_Personal || ${cfg.license.nodes} == 0 ]]; then
        return 0
    fi

    ID="regid.2019-10.com.cisco.CML_NODE_COUNT,1.0_2607650b-6ca8-46d5-81e5-e6688b7383c4"
    curl -vs -X "PATCH" \
        "$API/licensing/features" \
        -H "Authorization: Bearer $TOKEN" \
        -H "accept: application/json" \
        -H "Content-Type: application/json" \
        -d "{\"$ID\":${cfg.license.nodes}}"
}

# Ensure non-interactive Debian package installation
APT_OPTS="-o Dpkg::Options::=--force-confmiss -o Dpkg::Options::=--force-confnew"
APT_OPTS+=" -o DPkg::Progress-Fancy=0 -o APT::Color=0"
DEBIAN_FRONTEND=noninteractive
export APT_OPTS DEBIAN_FRONTEND

# Run the appropriate pre-setup function
setup_pre_${cfg.target}

# Only run the base setup when there's a provision directory both with
# Terraform and with Packer but not when deploying an AMI
if [ -d /provision ]; then
    base_setup
fi

# Only do a configure when this is not run within Packer / AMI building
if [ ! -f /tmp/PACKER_BUILD ]; then
    cml_configure ${cfg.target}
fi

