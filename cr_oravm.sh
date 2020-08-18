#!/bin/bash
#================================================================================
# Name:	cr_oravm.sh
# Type:	bash script
# Date:	23-April 2020
# From: Customer Architecture & Engineering (CAE) - Microsoft
#
# Copyright and license:
#
#       Licensed under the Apache License, Version 2.0 (the "License"); you may
#       not use this file except in compliance with the License.
#
#       You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
#       Unless required by applicable law or agreed to in writing, software
#       distributed under the License is distributed on an "AS IS" basis,
#       WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#
#       See the License for the specific language governing permissions and
#       limitations under the License.
#
#       Copyright (c) 2020 by Microsoft.  All rights reserved.
#
# Ownership and responsibility:
#
#       This script is offered without warranty by Microsoft Customer Engineering.
#       Anyone using this script accepts full responsibility for use, effect,
#       and maintenance.  Please do not contact Microsoft support unless there
#       is a problem with a supported Azure component used in this script,
#       such as an "az" command.
#
# Description:
#
#	Script to automate the creation of an Oracle database on a marketplace
#	Oracle image within Microsoft Azure, using the Azure CLI.
#
# Command-line Parameters:
#
#	Usage: ./cr_oravm.sh -G val -H val -N -O val -P val -S val -c val -d val -i val -n val -p val -r val -s val -u val -v -w val -z val
#
#	where:
#		-G resource-group-name	name of the Azure resource group (default: \"{owner}-{project}-rg\")
#		-H ORACLE_HOME		full path of ORACLE_HOME software (default: /u01/app/oracle/product/12.2.0/dbhome_1)
#		-N			skip storage account and network setup i.e. vnet, NSG, NSG rules (default: false)
#		-O owner-tag		name of the owner to use in Azure tags (default: Linux 'whoami')
#		-P project-tag		name of the project to use in Azure tags (default: oravm)
#		-S subscription		name of the Azure subscription (no default)
#		-c True|False		True is ReadWrite for OS / ReadOnly for data, False is None (default: True)
#		-d domain-name		IP domain name (default: internal.cloudapp.net)
#		-i instance-type	name of the Azure VM instance type (default: Standard_DS11-1_v2)
#		-n #data-disks		number of data disks to attach to the VM (default: 1)
#		-p Oracle-port		port number of the Oracle TNS Listener (default: 1521)
#		-r region		name of Azure region (default: westus)
#		-s ORACLE_SID		Oracle System ID (SID) value (default: oradb01)
#		-u urn			Azure URN for the VM from the marketplace (default: Oracle:Oracle-Database-Ee:12.2.0.1:12.2.20180725)
#		-v			set verbose output is true (default: false)
#		-w password		clear-text value of initial SYS and SYSTEM password in Oracle database (default: oracleA1)
#		-z data-disk-GB		size of each attached data-disk in GB (default: 4095)
#
# Expected command-line output:
#
#	Please see file "oravm_output.txt" at https://github.com/tigormanmsft/oravm.
#
# Usage notes:
#
#	1) Azure subscription must be specified with "-S" switch, always
#
#	2) Azure owner, default is output of "whoami" command in shell, can be
#	   specified using "-O" switch on command-line
#
#	3) Azure project, default is "oravm", can be specified using "-P"
#	   switch on command-line
#
#	4) Azure resource group, specify with "-G" switch or with a
#	   combination of "-O" (project owner tag) and "-P" (project name)
#	   values (default: "(project owner tag)-(project name)-rg").
#
#	   For example, if the project owner tag is "abc" and the project
#	   name is "beetlejuice", then by default the resource group is
#	   expected to be named "abc-beetlejuice-rg", unless changes have
#	   been specified using the "-G", "-O", or "-P" switches
#
#	5) Use the "-v" (verbose) switch to verify that program variables
#	   have the expected values
#
#	6) For users who are expected to use prebuilt storage accounts
#	   and networking (i.e. vnet, subnet, network security groups, etc),
#	   consider using the "-N" switch to accept these as prerequisites 
#
#	Please be aware that Azure owner (i.e. "-O") and Azure project (i.e. "-P")
#	are used to generate names for the Azure resource group, storage
#	account, virtual network, subnet, network security group and rules,
#	VM, and storage disks.  Use the "-v" switch to verify expected naming.
#
# Modifications:
#	TGorman	23apr20	written v0.1
#	TGorman	15jun20 various bug fixes for v0.2
#	TGorman	16jun20 move TEMP to temporary disk for v0.3
#	TGorman	22jun20	fix OsDisk Caching typo
#	SLuce and TGorman 22jun20 add Azure NetApp Files (ANF) storage for v0.4
#	TGorman	18aug20	fix minor issues for v0.5
#================================================================================
#
#--------------------------------------------------------------------------------
# Set global environment variables with default values...
#--------------------------------------------------------------------------------
_progVersion="0.5"
_outputMode="terse"
_azureOwner="`whoami`"
_azureProject="oravm"
_azureRegion="westus"
_azureSubscription=""
_workDir="`pwd`"
_skipSaVnetSubnetNsg="false"
_vmUrn="Oracle:Oracle-Database-Ee:12.2.0.1:12.2.20180725"
_vmDomain="internal.cloudapp.net"
_vmInstanceType="Standard_DS11-1_v2"
_vmOsDiskSize="32"
_vmOsDiskCaching="ReadWrite"
_vmDataDiskCaching="ReadOnly"
_vmDataDiskNbr=1
_vmDataDiskSzGB=4095
_vgName="vg_ora01"
_lvName="lv_ora01"
_oraSid="oradb01"
_oraHome="/u01/app/oracle/product/12.2.0/dbhome_1"
_oraInvDir="/u01/app/oraInventory"
_oraOsAcct="oracle"
_oraOsGroup="oinstall"
_oraCharSet="WE8ISO8859P15"
_oraMntDir="/u02"
_oraDataDir="${_oraMntDir}/oradata"
_oraFRADir="${_oraMntDir}/orarecv"
_oraSysPwd=oracleA1
_oraRedoSizeMB=500
_oraLsnrPort=1521
_oraMemPct=70
_oraMemType="AUTO_SGA"
_oraFraSzGB=40960
typeset -i _scsiDevNbr=24
declare -a _scsiDevList=("", "sdc" "sdd" "sde" "sdf" "sdg" "sdh" \
                             "sdi" "sdj" "sdk" "sdl" "sdm" "sdn" \
                             "sdo" "sdp" "sdq" "sdr" "sds" "sdt" \
                             "sdu" "sdv" "sdw" "sdx" "sdy" "sdz")
_saName="${_azureOwner}${_azureProject}sa"
_rgName="${_azureOwner}-${_azureProject}-rg"
_realRgName=""
_vnetName="${_azureOwner}-${_azureProject}-vnet"
_subnetName="${_azureOwner}-${_azureProject}-subnet"
_nsgName="${_azureOwner}-${_azureProject}-nsg"
_nicName="${_azureOwner}-${_azureProject}-nic01"
_pubIpName="${_azureOwner}-${_azureProject}-public-ip01"
_vmName="${_azureOwner}-${_azureProject}-vm01"
_logFile="${_workDir}/${_azureOwner}-${_azureProject}.log"
_ANFaccountName="${_azureOwner}-${_azureProject}-naa"
_ANFpoolName="${_azureOwner}-${_azureProject}-pool"
_ANFvolumeName="${_azureOwner}-${_azureProject}-vol"
_ANFsubnetName="${_azureOwner}-${_azureProject}-anfnet"
#
#--------------------------------------------------------------------------------
# Accept command-line parameter values to override default values (above)..
#--------------------------------------------------------------------------------
typeset -i _parseErrs=0
while getopts ":G:H:NO:P:S:c:d:i:n:p:r:s:u:vw:z:" OPTNAME
do
	case "${OPTNAME}" in
		G)	_realRgName="${OPTARG}"		;;
		H)	_oraHome="${OPTARG}"		;;
		N)	_skipSaVnetSubnetNsg="true"	;;
		O)	_azureOwner="${OPTARG}"		;;
		P)	_azureProject="${OPTARG}"	;;
		S)	_azureSubscription="${OPTARG}"	;;
		c)	typeset -u _TRUEorFALSE=${OPTARG}
			if [[ "${_TRUEorFALSE}" != "TRUE" ]]; then
				_vmOsDiskCaching="None"
				_vmDataDiskCaching="None"
			fi
			;;
		d)	_vmDomain="${OPTARG}"		;;
		i)	_vmInstanceType="${OPTARG}"	;;
		n)	_vmDataDiskNbr="${OPTARG}"	;;
		p)	_oraLsnrPort="${OPTARG}"	;;
		r)	_azureRegion="${OPTARG}"	;;
		s)	_oraSid="${OPTARG}"		;;
		u)	_vmUrn="${OPTARG}"		;;
		v)	_outputMode="verbose"		;;
		w)	_oraSysPwd="${OPTARG}"		;;
		z)	_vmDataDiskSzGB="${OPTARG}"	;;
		:)	echo "`date` - FAIL: expected \"${OPTARG}\" value not found"
			typeset -i _parseErrs=${_parseErrs}+1
			;;
		\?)	echo "`date` - FAIL: unknown command-line option \"${OPTARG}\""
			typeset -i _parseErrs=${_parseErrs}+1
			;;
	esac	
done
shift $((OPTIND-1))
#
#--------------------------------------------------------------------------------
# If any errors occurred while processing the command-line parameters, then display
# a usage message and exit with failure status...
#--------------------------------------------------------------------------------
if (( ${_parseErrs} > 0 ))
then
	echo "Usage: $0 -G val -H val -N -O val -P val -S val -c val -d val -i val -n val -p val -r val -s val -u val -v -w val -z val"
	echo "where:"
	echo "	-G resource-group-name	name of the Azure resource group (default: \"{owner}-{project}-rg\")"
	echo "	-H ORACLE_HOME		full path of the ORACLE_HOME software (default: /u01/app/oracle/product/12.2.0/dbhome_1)"
	echo "	-N			skip storage account and network setup i.e. vnet, NSG, NSG rules (default: false)"
	echo "	-O owner-tag		name of the owner to use in Azure tags (default: Linux 'whoami')"
	echo "	-P project-tag		name of the project to use in Azure tags (no default)"
	echo "	-S subscription		name of the Azure subscription (no default)"
	echo "	-c True|False		True is ReadWrite for OS / ReadOnly for data, False is None (default: True)"
	echo "	-d domain-name		IP domain name (default: internal.cloudapp.net)"
	echo "	-i instance-type	name of the Azure VM instance type (default: Standard_DS11-1_v2)"
	echo "	-n #data-disks		number of data disks to attach to the VM (default: 1)"
	echo "	-p Oracle-port		port number of the Oracle TNS Listener (default: 1521)"
	echo "	-r region		name of Azure region (default: westus)"
	echo "	-s ORACLE_SID		Oracle System ID (SID) value (default: oradb01)"
	echo "	-u urn			Azure URN for the VM from the marketplace (default: Oracle:Oracle-Database-Ee:12.2.0.1:12.2.20180725)"
	echo "	-v			set verbose output is true (default: false)"
	echo "	-w password		clear-text value of initial SYS and SYSTEM password in Oracle database (default: oracleA1)"
	echo "	-z data-disk-GB		size of each attached data-disk in GB (default: 4095)"
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Set script variables based on owner and project values...
#--------------------------------------------------------------------------------
if [[ "${_realRgName}" != "" ]]
then
	_rgName="${_realRgName}"
else
	_rgName="${_azureOwner}-${_azureProject}-rg"
fi
_saName="${_azureOwner}${_azureProject}sa"
_vnetName="${_azureOwner}-${_azureProject}-vnet"
_subnetName="${_azureOwner}-${_azureProject}-subnet"
_nsgName="${_azureOwner}-${_azureProject}-nsg"
_nicName="${_azureOwner}-${_azureProject}-nic01"
_pubIpName="${_azureOwner}-${_azureProject}-public-ip01"
_vmName="${_azureOwner}-${_azureProject}-vm01"
_logFile="${_workDir}/${_azureOwner}-${_azureProject}.log"
_ANFaccountName="${_azureOwner}-${_azureProject}-naa"
_ANFpoolName="${_azureOwner}-${_azureProject}-pool"
_ANFvolumeName="${_azureOwner}-${_azureProject}-vol"
_ANFsubnetName="${_azureOwner}-${_azureProject}-anfnet"
#
#--------------------------------------------------------------------------------
# Display variable values when output is set to "verbose"...
#--------------------------------------------------------------------------------
if [[ "${_outputMode}" = "verbose" ]]
then
	echo "`date` - DBUG: parameter _rgName is \"${_rgName}\""
	echo "`date` - DBUG: parameter _skipSaVnetSubnetNsg is \"${_skipSaVnetSubnetNsg}\""
	echo "`date` - DBUG: parameter _azureOwner is \"${_azureOwner}\""
	echo "`date` - DBUG: parameter _azureProject is \"${_azureProject}\""
	echo "`date` - DBUG: parameter _azureSubscription is \"${_azureSubscription}\""
	echo "`date` - DBUG: parameter _vmDataDiskCaching is \"${_vmDataDiskCaching}\""
	echo "`date` - DBUG: parameter _vmDomain is \"${_vmDomain}\""
	echo "`date` - DBUG: parameter _oraHome is \"${_oraHome}\""
	echo "`date` - DBUG: parameter _vmInstanceType is \"${_vmInstanceType}\""
	echo "`date` - DBUG: parameter _vmDataDiskNbr is \"${_vmDataDiskNbr}\""
	echo "`date` - DBUG: parameter _oraLsnrPort is \"${_oraLsnrPort}\""
	echo "`date` - DBUG: parameter _azureRegion is \"${_azureRegion}\""
	echo "`date` - DBUG: parameter _oraSid is \"${_oraSid}\""
	echo "`date` - DBUG: parameter _vmUrn is \"${_vmUrn}\""
	echo "`date` - DBUG: parameter _vmDataDiskSzGB is \"${_vmDataDiskSzGB}\""
	echo "`date` - DBUG: variable _progVersion is \"${_progVersion}\""
	echo "`date` - DBUG: variable _workDir is \"${_workDir}\""
	echo "`date` - DBUG: variable _logFile is \"${_logFile}\""
	echo "`date` - DBUG: variable _saName is \"${_saName}\""
	echo "`date` - DBUG: variable _vnetName is \"${_vnetName}\""
	echo "`date` - DBUG: variable _subnetName is \"${_subnetName}\""
	echo "`date` - DBUG: variable _nsgName is \"${_nsgName}\""
	echo "`date` - DBUG: variable _nicName is \"${_nicName}\""
	echo "`date` - DBUG: variable _pubIpName is \"${_pubIpName}\""
	echo "`date` - DBUG: variable _vmName is \"${_vmName}\""
	echo "`date` - DBUG: variable _vmOsDiskSize is \"${_vmOsDiskSize}\""
	echo "`date` - DBUG: variable _vmOsDiskCaching is \"${_vmOsDiskCaching}\""
	echo "`date` - DBUG: variable _vgName is \"${_vgName}\""
	echo "`date` - DBUG: variable _lvName is \"${_lvName}\""
	echo "`date` - DBUG: variable _oraInvDir is \"${_oraInvDir}\""
	echo "`date` - DBUG: variable _oraOsAcct is \"${_oraOsAcct}\""
	echo "`date` - DBUG: variable _oraOsGroup is \"${_oraOsGroup}\""
	echo "`date` - DBUG: variable _oraCharSet is \"${_oraCharSet}\""
	echo "`date` - DBUG: variable _oraMntDir is \"${_oraMntDir}\""
	echo "`date` - DBUG: variable _oraDataDir is \"${_oraDataDir}\""
	echo "`date` - DBUG: variable _oraFRADir is \"${_oraFRADir}\""
	echo "`date` - DBUG: variable _oraRedoSizeMB is \"${_oraRedoSizeMB}\""
	echo "`date` - DBUG: variable _oraMemPct is \"${_oraMemPct}\""
	echo "`date` - DBUG: variable _oraMemType is \"${_oraMemType}\""
	echo "`date` - DBUG: variable _oraFraSzGB is \"${_oraFraSzGB}\""
	echo "`date` - DBUG: variable _ANFaccountName is \"${_ANFaccountName}\""
	echo "`date` - DBUG: variable _ANFpoolName is \"${_ANFpoolName}\""
	echo "`date` - DBUG: variable _ANFvolumeName is \"${_ANFvolumeName}\""
	echo "`date` - DBUG: variable _ANFsubnetName is \"${_ANFsubnetName}\""
fi
#
#--------------------------------------------------------------------------------
# Verify that the requested number of data disks is less than the script's max...
#--------------------------------------------------------------------------------
if (( ${_vmDataDiskNbr} > ${_scsiDevNbr} )); then
	echo "`date` - FAIL: number of data disks must be <= ${_scsiDevNbr}" | tail -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Remove any existing logfile...
#--------------------------------------------------------------------------------
rm -f ${_logFile}
#
#--------------------------------------------------------------------------------
# Verify that the resource group exists...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az group exists -n ${_rgName}..." | tee -a ${_logFile}
if [[ "`az group exists -n ${_rgName}`" != "true" ]]; then
	echo "`date` - FAIL: resource group \"${_rgName}\" does not exist" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Set the default Azure subscription...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az account set..." | tee -a ${_logFile}
az account set -s "${_azureSubscription}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: ${_azureProject} - az account set" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Set the default Azure resource group and region/location...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az configure --defaults group location..." | tee -a ${_logFile}
az configure --defaults group=${_rgName} location=${_azureRegion} >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: ${_azureProject} - az configure --defaults group location" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# If the user elected to skip the creation of vnet, the NIC, the NSG, and the
# rules...
#--------------------------------------------------------------------------------
if [[ "${_skipSaVnetSubnetNsg}" = "false" ]]; then
	#
	#------------------------------------------------------------------------
	# Create an Azure storage account for this project...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az storage account create ${_saName}..." | tee -a ${_logFile}
	az storage account create \
		--name ${_saName} \
		--sku Standard_LRS \
		--access-tier Hot \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: ${_azureProject} - az storage account create ${_saName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create an Azure virtual network for this project...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az network vnet create ${_vnetName}..." | tee -a ${_logFile}
	az network vnet create \
		--name ${_vnetName} \
		--address-prefixes 10.0.0.0/16 \
		--subnet-name ${_subnetName} \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--subnet-prefixes 10.0.0.0/24 \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network vnet create ${_vnetName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create an Azure network security group for this project...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az network nsg create ${_nsgName}..." | tee -a ${_logFile}
	az network nsg create \
		--name ${_nsgName} \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network nsg create ${_nsgName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create a custom Azure network security group rule to permit SSH access...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az network nsg rule create default-all-ssh..." | tee -a ${_logFile}
	az network nsg rule create \
		--name default-all-ssh \
		--nsg-name ${_nsgName} \
		--priority 1000 \
		--direction Inbound \
		--protocol TCP \
		--source-address-prefixes \* \
		--source-port-ranges \* \
		--destination-address-prefixes \* \
		--destination-port-ranges 22 \
		--access Allow \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network nsg rule create default-all-ssh" | tee -a ${_logFile}
		exit 1
	fi
	#
fi
#
#--------------------------------------------------------------------------------
# Create an Azure public IP address object for use with the first VM...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az network public-ip create ${_pubIpName}..." | tee -a ${_logFile}
az network public-ip create \
	--name ${_pubIpName} \
	--tags owner=${_azureOwner} project=${_azureProject} \
	--allocation-method Static \
	--sku Basic \
	--version IPv4 \
	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az network public-ip create ${_pubIpName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Create an Azure network interface (NIC) object for use with the first VM...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az network nic create ${_nicName}..." | tee -a ${_logFile}
az network nic create \
	--name ${_nicName} \
	--vnet-name ${_vnetName} \
	--subnet ${_subnetName} \
	--network-security-group ${_nsgName} \
	--public-ip-address ${_pubIpName} \
	--tags owner=${_azureOwner} project=${_azureProject} \
	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az network nic create ${_nicName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Create the first Azure virtual machine (VM), intended to be used as the primary
# Oracle database server/host...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az vm create ${_vmName}..." | tee -a ${_logFile}
az vm create \
	--name ${_vmName} \
	--image ${_vmUrn}:latest \
	--admin-username ${_azureOwner} \
	--size ${_vmInstanceType} \
	--nics ${_nicName} \
	--os-disk-name ${_vmName}-osdisk \
	--os-disk-size-gb ${_vmOsDiskSize} \
	--os-disk-caching ${_vmOsDiskCaching} \
	--tags owner=${_azureOwner} project=${_azureProject} \
	--generate-ssh-keys \
	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az vm create ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Obtain the public IP addresses for future use within the script...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az network public-ip show ${_pubIpName}..." | tee -a ${_logFile}
_ipAddr=`az network public-ip show --name ${_pubIpName} | \
	 jq '. | {ipaddr: .ipAddress}' | \
	 grep ipaddr | \
	 awk '{print $2}' | \
	 sed 's/"//g'`
if (( $? != 0 )); then
	echo "`date` - FAIL: az network public-ip show ${_pubIpName}" | tee -a ${_logFile}
	exit 1
fi 
ssh-keygen -f "${HOME}/.ssh/known_hosts" -R ${_ipAddr} >> ${_logFile} 2>&1
echo "`date` - INFO: public IP ${_ipAddr} for ${_vmName}..." | tee -a ${_logFile}
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create a directory mount-point for the soon-to-be-created
# filesystem in which Oracle database files will reside...
#--------------------------------------------------------------------------------
echo "`date` - INFO: mkdir ${_oraMntDir} on ${_vmName}..." | tee -a ${_logFile}
ssh -o StrictHostKeyChecking=no ${_azureOwner}@${_ipAddr} "sudo mkdir -p ${_oraMntDir}"
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo mkdir -p ${_oraMntDir} on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# If no data disks are requested on the VM, then deploy Azure NetApp Files...
#--------------------------------------------------------------------------------
if (( ${_vmDataDiskNbr} <= 0 )); then
	echo "`date` - INFO: no data disks requested, Azure NetApp Files it is!" | tee -a ${_logFile}
	#
	#--------------------------------------------------------------------------------
	# Obtain the private IP address of the VM for future use within the script...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: az network nic ip-config show ${_nicName}..." | tee -a ${_logFile}
	_privateipAddr=`az network nic ip-config show --nic-name ${_nicName} --name ipconfig1 | \
		jq '. | {ipaddr: .privateIpAddress}' | \
		grep ipaddr | \
		awk '{print $2}' | \
		sed 's/"//g'`
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network nic ip-config show ${_nicName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	## Create Azure NetApp Files Delegated Subnet
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: az network vnet subnet create ${_ANFsubnetName}..." | tee -a ${_logFile}
	az network vnet subnet create \
		--name ${_ANFsubnetName} \
		--vnet-name ${_vnetName} \
		--delegation Microsoft.Netapp/volumes \
		--address-prefixes 10.0.1.0/24 \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network vnet subnet create ${_ANFsubnetName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	## Create the Azure NetApp Files (ANF) NetApp Account
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: az netappfiles account create ${_ANFaccountName}..." | tee -a ${_logFile}
	az netappfiles account create \
		--account-name ${_ANFaccountName} \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az netappfiles account create ${_ANFaccountName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	## Create the ANF Capacity Pool
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: az netappfiles pool create ${_ANFpoolName}..." | tee -a ${_logFile}
	az netappfiles pool create \
		--account-name ${_ANFaccountName} \
		--pool-name ${_ANFpoolName} \
		--service-level Premium \
		--size 4 \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az netappfiles pool create ${_ANFpoolName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	## Create the ANF Volume
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: az netappfiles volume create ${_ANFvolumeName}..." | tee -a ${_logFile}
	az netappfiles volume create \
		--account-name ${_ANFaccountName} \
		--pool-name ${_ANFpoolName} \
		--volume-name ${_ANFvolumeName} \
		--file-path ${_ANFvolumeName}\
		--usage-threshold 500 \
		--vnet ${_vnetName} \
		--subnet ${_ANFsubnetName} \
		--protocol-types NFSv4.1 \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az netappfiles volume create ${_ANFvolumeName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	## Add a rule to the NFS export policy for our VM at index 2
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: az netappfiles volume export-policy create for ${_privateipAddr}..." | tee -a ${_logFile}
	az netappfiles volume export-policy add \
		--account-name ${_ANFaccountName} \
		--pool-name ${_ANFpoolName} \
		--volume-name ${_ANFvolumeName} \
		--allowed-clients ${_privateipAddr} \
		--rule-index 2 \
		--nfsv41 true \
		--nfsv3 false \
		--cifs false \
		--unix-read-only false \
		--unix-read-write true \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az netappfiles volume export-policy create for ${_privateipAddr}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	## Remove the default rule from the volume export policy at index 1
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: az netappfiles volume export-policy remove for 0.0.0.0/0..." | tee -a ${_logFile}
	az netappfiles volume export-policy remove \
		--account-name ${_ANFaccountName} \
		--pool-name ${_ANFpoolName} \
		--volume-name ${_ANFvolumeName} \
		--rule-index 1 \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az netappfiles volume export-policy remove for 0.0.0.0/0" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	## Get the Azure NetApp Files endpoint IP address
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: az netappfiles volume show ${_ANFvolumeName}..." | tee -a ${_logFile}
	_ANFipAddr=`az netappfiles volume show \
			--account-name ${_ANFaccountName} \
			--pool-name ${_ANFpoolName} \
			--volume-name ${_ANFvolumeName} | \
			jq '.mountTargets[0].ipAddress' | \
			sed 's/"//g'`
	if (( $? != 0 )); then
		echo "`date` - FAIL: az netappfiles volume show ${_ANFvolumeName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# SSH into the first VM to mount the newly created Azure NetApp Files
	# NFS volume in which the Oracle database files will reside...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: mount ${_ANFvolumeName} on ${_vmName}..." | tee -a ${_logFile}
	ssh -o StrictHostKeyChecking=no ${_azureOwner}@${_ipAddr} "\
		sudo mount -t nfs \
			-o rw,hard,rsize=65536,wsize=65536,sec=sys,vers=4.1,tcp \
			${_ANFipAddr}:/${_ANFvolumeName} ${_oraMntDir}"
	if (( $? != 0 )); then
		echo "`date` - FAIL: mount ${_ANFvolumeName} on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	#
else # ...else if _nbrDataDisks > 0, then use managed disks for database storage...
	#
	#--------------------------------------------------------------------------------
	# SSH into the first VM to install the "LVM2" package using the Linux "yum"
	# utility...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: yum install lvm2 on ${_vmName}..." | tee -a ${_logFile}
	ssh ${_azureOwner}@${_ipAddr} "sudo yum install -y lvm2" >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: yum install lvm2 on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# Loop to attach the specified number of data disks...
	#--------------------------------------------------------------------------------
	typeset -i _diskAttached=0
	_pvList=""
	while (( ${_diskAttached} < ${_vmDataDiskNbr} )); do
		#
		#------------------------------------------------------------------------
		# Increment the counter of attached data disks...
		#------------------------------------------------------------------------
		typeset -i _diskAttached=${_diskAttached}+1
		_diskNbr="`echo ${_diskAttached} | awk '{printf("%02d\n",$1)}'`"
		#
		#------------------------------------------------------------------------
		# Create and attach a data disk to the VM...
		#------------------------------------------------------------------------
		echo "`date` - INFO: az vm disk attach (${_vmName}-datadisk${_diskNbr})..." | tee -a ${_logFile}
		az vm disk attach \
			--new \
			--name ${_vmName}-datadisk${_diskNbr} \
			--vm-name ${_vmName} \
			--caching ${_vmDataDiskCaching} \
			--size-gb ${_vmDataDiskSzGB} \
			--sku Premium_LRS \
			--verbose >> ${_logFile} 2>&1
		if (( $? != 0 )); then
			echo "`date` - FAIL: az vm disk create ${_vmName} (${_diskAttached})" | tee -a ${_logFile}
			exit 1
		fi
		#
		#------------------------------------------------------------------------
		# Identify the name of the SCSI device from the array initialized at the
		# beginning of the script, and derive the name of the single partition on
		# the SCSI device, then add to the list of SCSI partitions for later use...
		#------------------------------------------------------------------------
		_scsiDev="/dev/${_scsiDevList[${_diskAttached}]}"
		_pvName="${_scsiDev}1"
		_pvList="${_pvList}${_pvName} "
		#
		#------------------------------------------------------------------------
		# SSH into the VM to create a GPT label on the SCSI device...
		#------------------------------------------------------------------------
		echo "`date` - INFO: parted ${_scsiDev} mklabel on ${_vmName}..." | tee -a ${_logFile}
		ssh ${_azureOwner}@${_ipAddr} "sudo parted ${_scsiDev} mklabel gpt" >> ${_logFile} 2>&1
		if (( $? != 0 )); then
			echo "`date` - FAIL: parted ${_scsiDev} mklabel gpt on ${_vmName}" | tee -a ${_logFile}
			exit 1
		fi
		#
		#------------------------------------------------------------------------
		# SSH into the VM to create a single primary partitition consuming the
		# entire SCSI device...
		#------------------------------------------------------------------------
		echo "`date` - INFO: parted ${_scsiDev} mkpart primary on ${_vmName}..." | tee -a ${_logFile}
		ssh ${_azureOwner}@${_ipAddr} "sudo parted -a opt ${_scsiDev} mkpart primary ext4 0% 100%" >> ${_logFile} 2>&1
		if (( $? != 0 )); then
			echo "`date` - FAIL: yum parted mkpart -a opt ${_scsiDev} primary ext4 0% 100% on ${_vmName}" | tee -a ${_logFile}
			exit 1
		fi
		#
		#------------------------------------------------------------------------
		# SSH into the VM to create a physical partition from the SCSI partition...
		#------------------------------------------------------------------------
		echo "`date` - INFO: pvcreate ${_pvName} on ${_vmName}..." | tee -a ${_logFile}
		ssh ${_azureOwner}@${_ipAddr} "sudo pvcreate ${_pvName}" >> ${_logFile} 2>&1
		if (( $? != 0 )); then
			echo "`date` - FAIL: pvcreate ${_pvName} on ${_vmName}" | tee -a ${_logFile}
			exit 1
		fi
		#
	done
	#
	#--------------------------------------------------------------------------------
	# Create a volume group from the list of physcial volumes...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: vgcreate ${_vgName} ${_pvList} on ${_vmName}..." | tee -a ${_logFile}
	ssh ${_azureOwner}@${_ipAddr} "sudo vgcreate ${_vgName} ${_pvList}" >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: vgcreate ${_vgName} ${_pvList} on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# Obtain the PE Size and Total # of PEs in the volume group, to obtain the size
	# (in MiB) of all the physical volumes in the volume group, which will be the
	# size of the soon-to-be-created logical volume...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: vgdisplay ${_vgName} on ${_vmName}..." | tee -a ${_logFile}
	_peTotal=`ssh ${_azureOwner}@${_ipAddr} "sudo vgdisplay ${_vgName} | grep 'Total PE' | awk '{print \\\$3}'"`
	if (( $? != 0 )); then
		echo "`date` - FAIL: vgdisplay ${_vgName} | grep 'Total PE' on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	_peSize=`ssh ${_azureOwner}@${_ipAddr} "sudo vgdisplay ${_vgName} | grep 'PE Size' | awk '{print \\\$3}'"`
	if (( $? != 0 )); then
		echo "`date` - FAIL: vgdisplay ${_vgName} | grep 'PE Size' on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	typeset -i _lvSize=`echo ${_peTotal} ${_peSize} | awk '{printf("%d\n",$1*$2)}'`
	if (( $? != 0 )); then
		echo "`date` - FAIL: awk '{printf(${_peTotal} * ${_peSize})" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# SSH into the VM to create a logical volume from the allocated data disks...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: lvcreate ${_vgName} on ${_vmName}..." | tee -a ${_logFile}
	ssh ${_azureOwner}@${_ipAddr} "sudo lvcreate -n ${_lvName} -i ${_vmDataDiskNbr} -I 1024k -L ${_lvSize}m ${_vgName} ${_pvList}" >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: lvcreate -n ${_lvName} -i ${_vmDataDiskNbr} -I 1024k -L ${_lvSize}m ${_vgName} ${_pvList} on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# SSH into the VM to create an EXT4 filesystem on the logical volume...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: mkfs.ext4 /dev/${_vgName}/${_lvName} on ${_vmName}..." | tee -a ${_logFile}
	ssh ${_azureOwner}@${_ipAddr} "sudo mkfs.ext4 /dev/${_vgName}/${_lvName}" >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: mkfs.ext4 /dev/${_vgName}/${_lvName} on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# SSH into the VM to mount the filesystem on "/u02"...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: mount /dev/${_vgName}/${_lvName} ${_oraMntDir} on ${_vmName}..." | tee -a ${_logFile}
	ssh ${_azureOwner}@${_ipAddr} "sudo mount /dev/${_vgName}/${_lvName} ${_oraMntDir}" >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: mount /dev/${_vgName}/${_lvName} ${_oraMntDir} on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	#
fi
#
#------------------------------------------------------------------------
# SSH into first VM to create sub-directories for the Oracle database
# files and for the Oracle Flash Recovery Area (FRA) files...
#------------------------------------------------------------------------
echo "`date` - INFO: mkdir ${_oraDataDir} ${_oraFRADir} on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo mkdir -p ${_oraDataDir} ${_oraFRADir}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo mkdir -p ${_oraDataDir} ${_oraFRADir} on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to set the OS account:group ownership of the
# directory mount-point...
#--------------------------------------------------------------------------------
echo "`date` - INFO: chown -R ${_oraMntDir} on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo chown -R ${_oraOsAcct}:${_oraOsGroup} ${_oraMntDir}"
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chown -R ${_oraMntDir} on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to copy the file "oraInst.loc" from the current Oracle
# Inventory default location into the "/etc" system directory, where it can be
# easily found by any Oracle programs accessing the host.  Set the ownership and
# permissions appropriately for the copied file...
#--------------------------------------------------------------------------------
echo "`date` - INFO: copy oraInst.loc file on ${_vmName}" | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo cp ${_oraInvDir}/oraInst.loc /etc" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo cp ${_azureOwner}@${_ipAddr}:${_oraInvDir}/oraInst.loc /etc" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr} "sudo chown ${_oraOsAcct}:${_oraOsGroup} /etc/oraInst.loc" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chown ${_oraOsAcct}:${_oraOsGroup} /etc/oraInst.loc" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr} "sudo chmod 644 /etc/oraInst.loc" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chmod 644 /etc/oraInst.loc" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to run the Oracle Database Creation Assistant (DBCA)
# program to create a new primary Oracle database...
#--------------------------------------------------------------------------------
echo "`date` - INFO: dbca -createDatabase ${_oraSid} on ${_vmName1} (be prepared - long wait)..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo su - ${_oraOsAcct} -c \"\
	export ORACLE_SID=${_oraSid}
	export ORACLE_HOME=${_oraHome}
	export PATH=${_oraHome}/bin:\${PATH}
	unset TNS_ADMIN
	dbca -silent -createDatabase \
		-gdbName ${_oraSid} \
		-templateName ${_oraHome}/assistants/dbca/templates/General_Purpose.dbc \
		-sid ${_oraSid} \
		-sysPassword ${_oraSysPwd} \
		-systemPassword ${_oraSysPwd} \
		-characterSet ${_oraCharSet} \
		-createListener LISTENER:${_oraLsnrPort} \
		-storageType FS \
		-datafileDestination ${_oraDataDir} \
		-enableArchive TRUE \
		-memoryMgmtType ${_oraMemType} \
		-memoryPercentage ${_oraMemPct} \
		-initParams db_create_online_log_dest_1=${_oraFRADir} \
		-recoveryAreaDestination ${_oraFRADir} \
		-recoveryAreaSize ${_oraFraSzGB} \
		-redoLogFileSize ${_oraRedoSizeMB}\"" | tee -a ${_logFile}
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo su - ${_oraOsAcct} dbca -createDatabase ${_oraSid} on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Create the "oradata" subdirectory on the temporary disk within the "/mnt/resource"
# directory of the Linux VM, owned by the Oracle OS account...
#--------------------------------------------------------------------------------
echo "`date` - INFO: mkdir -p /mnt/resource/oradata on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo mkdir -p /mnt/resource/oradata" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo mkdir -p /mnt/resource/oradata on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
echo "`date` - INFO: chown ${_oraOsAcct}:${_oraOsGroup} /mnt/resource/oradata on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo chown ${_oraOsAcct}:${_oraOsGroup} /mnt/resource/oradata" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chown ${_oraOsAcct}:${_oraOsGroup} /mnt/resource/oradata on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Create a "temporary use" temporary tablespace (named TEMPTMPTEMP), make it
# default, then drop and recreate the TEMP tablespace on the VM temporary disk,
# then make TEMP the default and clean up the "temporary use" TEMPTMPTEMP
# tablespace...
#--------------------------------------------------------------------------------
echo "`date` - INFO: move TEMP tablespace to temporary disk on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo su - ${_oraOsAcct} -c \"
export ORACLE_SID=${_oraSid}
export ORACLE_HOME=${_oraHome}
export PATH=${_oraHome}/bin:\${PATH}
unset TNS_ADMIN
sqlplus -S -L / as sysdba << __EOF__
whenever oserror exit failure
whenever sqlerror exit failure
alter session set db_create_file_dest='/mnt/resource/oradata';
create temporary tablespace temptmptemp tempfile size 10M;
alter database default temporary tablespace temptmptemp;
host sleep 5
drop tablespace temp including contents and datafiles;
create temporary tablespace temp
	tempfile size 512M autoextend on next 512M maxsize unlimited
        extent management local uniform size 1M;
alter database default temporary tablespace temp;
host sleep 5
drop tablespace temptmptemp including contents and datafiles;
exit success
__EOF__\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: move TEMP tablespace to temporary disk on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Completed the setup successfully!  End of program...
#--------------------------------------------------------------------------------
echo "`date` - INFO: completed successfully!" | tee -a ${_logFile}
exit 0
