# oravm
Azure CLI (bash) script to fully automate the creation of an Azure VM to run Oracle database

## Description:

      Script to automate the creation of an Oracle database on a marketplace
      Oracle image within Microsoft Azure, using the Azure CLI.

## Command-line Parameters:

## Usage:

        $0 -G val -H val -N -O val -P val -S val -c val -d val -i val -n val -p val -r val -s val -u val -v -w val -z val"

### where:

        -G resource-group-name  name of the Azure resource group (default: \"{owner}-{project}-rg\")"
        -H ORACLE_HOME          full path of the ORACLE_HOME software (default: /u01/app/oracle/product/12.2.0/dbhome_1)"
        -N                      skip past network setup i.e. vnet, NSG, NSG rules (default: false)"
        -O owner-tag            name of the owner to use in Azure tags (no default)"
        -P project-tag          name of the project to use in Azure tags (no default)"
        -S subscription         name of the Azure subscription (no default)"
        -c None|ReadOnly        caching of managed disk for data (default: ReadOnly)"
        -d domain-name          IP domain name (default: internal.cloudapp.net)"
        -i instance-type        name of the Azure VM instance type (default: Standard_DS11-1_v2)"
        -n #data-disks          number of data disks to attach to the VM (default: 1)"
        -p Oracle-port          port number of the Oracle TNS Listener (default: 1521)"
        -r region               name of Azure region (default: westus)"
        -s ORACLE_SID           Oracle System ID (SID) value (default: oradb01)"
        -u urn                  Azure URN for the VM from the marketplace (default: Oracle:Oracle-Database-Ee:12.2.0.1:12.2.20180725)"
        -v                      set verbose output is true (default: false)"
        -w password             clear-text value of initial SYS and SYSTEM password in Oracle database (default: oracleA1)"
        -z data-disk-GB         size of each attached data-disk in GB (default: 4095)"

## Usage notes:

### Expected prerequisites:
        1) Azure subscription, specify with "-S" switch, as explained
           above (default: none)

        2) Azure resource group, specify with "-G" switch or with a
           combination of "-O" (project owner tag) and "-P" (project name)
           values (default: "(project owner tag)-(project name)-rg").

           For example, if the project owner tag is "abc" and the project
           name is "beetlejuice", then by default the resource group is
           expected to be named "abc-beetlejuice-rg", unless changes have
           been specified using the "-G", "-O", or "-P" switches

        3) Use the "-v" (verbose) switch to verify that program variables
           have the expected values

# Usage examples

(under construction -- please email "tigorman@micrsoft.com" to get moving on this!)
