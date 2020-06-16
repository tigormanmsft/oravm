# oravm
Azure CLI (bash) script to fully automate the creation of an Azure VM to run Oracle database

## Description:

      Script to automate the creation of an Oracle database on a marketplace
      Oracle image within Microsoft Azure, using the Azure CLI.

## Command-line Parameters:

## Usage:

        ./cr_oravm.sh -G val -H val -N -O val -P val -S val -c val -d val -i val -n val -p val -r val -s val -u val -v -w val -z val

### where:

        -G resource-group-name  name of the Azure resource group (default: \"{owner}-{project}-rg\")"
        -H ORACLE_HOME          full path of the ORACLE_HOME software (default: /u01/app/oracle/product/12.2.0/dbhome_1)"
        -N                      skip storage account and network setup i.e. vnet, NSG, NSG rules (default: false)"
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

        4) For users who are expected to use prebuilt storage accounts
           and networking (i.e. vnet, subnet, network security groups, etc),
           consider using the "-N" switch to accept these as prerequisites 

# Usage examples

For example, to create an E16ds v4 VM with four 2 TiB data disks on the Azure marketplace image for Oracle19c, please try these command-line options...

      ./cr_oravm.sh \
            -v \
            -S "ExampleSubscriptionName" \
            -P ora19c \
            -i Standard_E2ds_v4 
            -n 2 \
            -z 2048 \
            -p 1522 \
            -s ORCL \
            -r westus2 \
            -u Oracle:oracle-database-19-3:oracle-db-19300:19.3.0 \
            -H /u01/app/oracle/product/19.0.0/dbhome_1

This will have the following impact, besides generating the example output displayed in the "oravm_output.txt" file...

 - the "-v" switch will display all script variables values and parameter values at the beginning of the execution
 - set the Azure subscription used by the session
 - set the Azure "project" value to "ora19c", which will impact the naming of all objects and tags
 - build a VM sized at E2ds v4 using the marketplace Oracle19c image with an OS disk and two data disks of 2 TiB and an Oracle database named "ORCL" on network port 1522 in the West US 2 region.
 - please note that the marketplace Oracle19c image has ORACLE_HOME at a specific location
