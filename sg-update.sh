#!/usr/bin/env bash

REGION="${1:-us-east-1}"
OLD_CIDR="${2:-10.0.0.1/32}"
NEW_CIDR="${3:-10.0.0.2/32}"
NEW_CIDR_DESC="${4:-vladimirz\'s home ip}"


# find rules with old CIDR
rules=$(aws ec2 describe-security-groups --region ${REGION} --filters Name=ip-permission.cidr,Values=${OLD_CIDR} --query 'SecurityGroups[].[GroupId, IpPermissions[].[IpProtocol, FromPort, ToPort, IpRanges[?CidrIp == `'"${OLD_CIDR}"'`].CidrIp | [0]]]' | grep -v None | awk '{OFS=","; if (NF == 1) sg=$1; if (NF == 4) print sg "," $1, $2, $3}')
echo "$rules"

# confirmation
confirm(){
    read -r -p "Are you sure? [y/N]" response
    
    case ${response} in
        [yY][eE][sS]|[yY]) 
            change_cidr;;
        *) 
            exit;;
    esac
}

# change CIDR
change_cidr() {

    while IFS=',' read -r -a line
    do
    #aws ec2 authorize-security-group-ingress --group-id ${line[0]} --ip-permissions IpProtocol=${line[1]},FromPort=${line[2]},ToPort=${line[3]},IpRanges='[{CidrIp='${NEW_CIDR}',Description='${NEW_CIDR_DESC}'}]' --region ${REGION}
    echo "Group ID ${line[0]} is changed"
    done < <(printf '%s\n' "$rules")

}

confirm

# echo "aws ec2 authorize-security-group-ingress \
#     --group-id ${sg-id} \
#     --ip-permissions \
#     IpProtocol=${protocol},FromPort=${fromPort},ToPort=${toPort},IpRanges='[{CidrIp=${CIDR},Description=\"IL office (Cellcom)\"}]'"
