#!/usr/bin/env bash

DRY_RUN=""

DEFAULT_DESC=$(echo ${USER}-home-ip)
DEFAULT_NEW_CIDR=$(echo $(curl -s ident.me)/32)
AWS_CONFIG_DEFAULT_REGION=$(aws configure get region)
DEFAULT_AWS_REGION="${AWS_CONFIG_DEFAULT_REGION:-us-east-1}"

OLD_CIDR="${1:-1.1.1.1/32}"
NEW_CIDR="${2:-$DEFAULT_NEW_CIDR}"
REGION="${3:-$DEFAULT_AWS_REGION}"
NEW_CIDR_DESC="${4:-$DEFAULT_DESC}"

echo "AWS REGION = ${REGION}"
echo "OLD CIDR = ${OLD_CIDR}"
echo "NEW CIDR = ${NEW_CIDR}"
echo ""

# find rules with old CIDR
rules=$(aws ec2 describe-security-groups --region ${REGION} --output text --filters Name=ip-permission.cidr,Values=${OLD_CIDR} --query 'SecurityGroups[].[GroupId, IpPermissions[].[IpProtocol, FromPort, ToPort, IpRanges[?CidrIp == `'"${OLD_CIDR}"'`].CidrIp | [0]]]' | grep -v None | awk '{OFS=","; if (NF == 1) sg=$1; if (NF == 4) print sg "," $1, $2, $3}')

echo -e "Old CIDR is used in next security groups: \n"
echo -e "${rules} \n"

# confirmation
confirm(){
    read -r -p "${1:-Are you sure? [y/N]} " response
    
    case ${response} in
        [yY][eE][sS]|[yY]) 
            true;;
        *) 
            exit;;
    esac
}

# change CIDR
add_cidr() {

    local CIDR=${1:-NEW_CIDR}

    while IFS=',' read -r -a line
    do
    echo "Adding access from ${line[3]} to ${line[3]} ports in security group ID ${line[0]} from ${NEW_CIDR}"

    if [ -z "${DRY_RUN}" ]; then
        aws ec2 authorize-security-group-ingress --group-id ${line[0]} --ip-permissions IpProtocol=${line[1]},FromPort=${line[2]},ToPort=${line[3]},IpRanges='[{CidrIp='${NEW_CIDR}',Description='${NEW_CIDR_DESC}'}]' --region ${REGION}
    else
        echo "aws ec2 authorize-security-group-ingress --group-id ${line[0]} --ip-permissions IpProtocol=${line[1]},FromPort=${line[2]},ToPort=${line[3]},IpRanges='[{CidrIp='${NEW_CIDR}',Description='${NEW_CIDR_DESC}'}]' --region ${REGION}"
    fi
    done < <(printf '%s\n' "$rules")
    echo -e "\nDone\n"
}

remove_cidr() {

    local CIDR=${1:-OLD_CIDR}
    while IFS=',' read -r -a line
    do
    echo "Removing access from ${line[3]} to ${line[3]} ports in security group ID ${line[0]} from ${OLD_CIDR}"

    if [ -z "${DRY_RUN}" ]; then
        aws ec2 revoke-security-group-ingress --group-id ${line[0]} --ip-permissions IpProtocol=${line[1]},FromPort=${line[2]},ToPort=${line[3]},IpRanges='[{CidrIp='${OLD_CIDR}'}]' --region ${REGION}
    else
        echo "aws ec2 revoke-security-group-ingress --group-id ${line[0]} --ip-permissions IpProtocol=${line[1]},FromPort=${line[2]},ToPort=${line[3]},IpRanges='[{CidrIp='${OLD_CIDR}'}]' --region ${REGION}"
    fi

    done < <(printf '%s\n' "$rules")
    echo -e "\nDone"
}

confirm "Are you sure you want to add access from CIDR ${NEW_CIDR} to those rules? [y/N] " && add_cidr
confirm "Do you want to remove access from CIDR ${OLD_CIDR}? [y/N] " && remove_cidr