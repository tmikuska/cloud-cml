# README

Version 0.2.0, January 23 2024

This repository includes scripts, tooling and documentation to provision an instance of Cisco Modeling Labs (CML) in various cloud services. Currently supported are Amazon Web Services (AWS) and Microsoft Azure.

> **IMPORTANT** The CML deployment procedure and the toolchain / code provided in this repository are **considered "experimental"**. If you encounter any errors or problems that might be related to the code in this repository then please open an issue on the [Github issue tracker for this repository](https://github.com/CiscoDevNet/cloud-cml/issues).

## General requirements

The tooling uses Terraform to deploy CML instances in the Cloud. It's therefore required to have a functional Terraform installation on the computer where this tool chain should be used.

Furthermore, the user needs to have access to the cloud service. E.g. credentials and permissions are needed to create and modify the required resources. Required resources are

- service accounts
- storage services
- compute and networking services

The toolchain / build scripts and Terraform can be installed on the on-prem CML controller or, when this is undesirable due to support concerns, on a separate Linux instance.

That said, it *should be possible* to run the tooling also on macOS with tools installed via [Homebrew](https://brew.sh/). Or on Windows with WSL. However, this hasn't been tested by us.

### Preparation

Some of the steps and procedures outlined below are preparation steps and only need to be done once. Those are

- cloning of the repository
- installation of software (Terraform, cloud provider CLI tooling)
- creating and configuring of a service account, including the creation of associated access credentials
- creating the storage resources and uploading images and software into it
- creation of an SSH key pair and making the public key available to the cloud service
- editing the `config.yml` configuration file including the selection of the cloud service, an instance flavor, region, license token and other parameters

### Terraform installation

Terraform can be downloaded for free from [here](https://developer.hashicorp.com/terraform/downloads). This site has also instructions how to install it on various supported platforms.

Deployments of CML using Terraform were tested using version 1.4.6 on Ubuntu Linux.

```plain
$ terraform version
Terraform v1.4.6
on linux_amd64
+ provider registry.terraform.io/ciscodevnet/cml2 v0.6.2
+ provider registry.terraform.io/hashicorp/aws v4.67.0
+ provider registry.terraform.io/hashicorp/random v3.5.1
$
```

It is assumed that the CML cloud repository was cloned to the computer where Terraform was installed. The following command are all executed within the directory that has the cloned repositories. In particular, this `README.md`, the `main.tf` and the `config.yml` files, amongst other files.

When installed, run `terraform init` to initialize Terraform. This will download the required providers and create the state files.

## Cloud specific instructions

See the documentation directory for cloud specific instructions:

- [Amazon Web Services (AWS)](documentation/AWS.md)
- [Microsoft Azure](documentation/Azure.md)

EOF
