#!/bin/bash

# PLEASE DO NOT EDIT THIS SCRIPT
#
# For what it does this program has an over-abundance of safety checks.
# These are in place to counterbalance a number of serious issues discovered
# in our supply chain. The steps need to be followed as designed, in order
# to maintain our confidence in workload completion and tracking
#
# Thank you!

set -eu
set -o pipefail


[[ "$EUID" -ne 0 ]] && echo "You must run this program as root" && exit 1

if [[  "$#" -lt 2 ]] ; then
  echo -e "\nExpecting one source and at least one destination drive serial number\n\t./fil-cloner.bash ZA123456 WKD12345 ZA456789 ...\n\n"
  exit 1
fi

dstDrives=()

for arg in "$@"; do \
  drvMatches=( /dev/disk/by-id/*-ST8000*"$arg" )

  if ! [[ -e ${drvMatches[0]} ]]; then
    echo "Serial number '$arg' does not match any filecoin-discover drive on this system"
    exit 1
  elif [[ "${#drvMatches[@]}" -gt 1 ]]; then
    echo "Serial number '$arg' matches more than one drive on this system"
    exit 1
  fi

  if lsblk -n -o mountpoint "${drvMatches[0]}" | grep -v '^$' ; then
    echo "Drive with serial number '$arg' seems to be mounted as listed above"
    exit 1
  fi
  if lsblk -n -o name,type "${drvMatches[0]}" | grep -vE '(disk|part)$' ; then
    echo "Drive with serial number '$arg' seems to be a building block for another device"
    exit 1
  fi

  dstDrives+=( "${drvMatches[0]}" )
done

srcDrive="${dstDrives[0]}"
dstDrives=("${dstDrives[@]:1}")

scratchfn="$( mktemp -t tmp.XXXXXXXXXX )"
! [[ -r "$scratchfn" ]] && echo "Creation of the templog failed for some reason" && exit 1

onEnd() {
  ex=$?
  set +e

  curl -s "https://fil-discover-drive-clone.s3-ap-east-1.amazonaws.com/$(date +'%s.%N')_${ex}_$( <<<"${srcDrive} ${dstDrives[@]}" sed 's/ /_/g' | sed 's/\/dev\/disk\/by-id\///g' | sed 's/\//-/g' )" \
    -H "x-amz-acl: bucket-owner-full-control" -T "$scratchfn"

  ! [[ "$ex" = "0" ]] && echo -e "\nSomething went wrong... please DO NOT SHIP the drives as-is, retry instead!!!\n\nIf the problem persists contact @ribasushi\n\n"

  rm -f "$scratchfn"
}

trap onEnd EXIT

exec 3>&2
exec 2> >( tee -a "$scratchfn" >&3)
exec 1> >( tee -a "$scratchfn" >&3)

nl=$'\n'
IFS="$nl"
now=$( date -u +'%H:%M:%S' )
read -p "${nl}It is $now UTC and you are about to IRREVERSIBLY write the contents of${nl}${nl}${srcDrive}${nl}  to${nl}${dstDrives[*]}${nl}${nl}If this is what you intended - enter the current minute MM: " -r
if [[ "$REPLY" == "" ]] || [[ "$REPLY" != "$( cut -d ':' -f 2 <<<$now )" ]]; then
  echo "Not the expected answer, aborting"
  exit 1
fi

echo -e "\nStarting replication...\nNOTE wait for the prompt to return, there might be a 30 second delay after the last printout\n\n"

IFS=" "
finCmd="dd bs=32M status=progress if=$srcDrive"
for d in "${dstDrives[@]}"; do
  finCmd="$finCmd | tee >( dd bs=32M status=none of=$d)"
done
finCmd="$finCmd > /dev/null"
eval $finCmd

echo -e "\n\n<3 <3 <3\nLooks like everything went great!\n<3 <3 <3\n\n"
