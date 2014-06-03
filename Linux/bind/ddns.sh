#!/bin/bash


ZONE=vnic.scaling.local.
DDDATA=/var/tmp/DDDATA

NSUPDATE=/usr/bin/nsupdate
RNDCKEY="rndc-key:+rzjWqamRn90KjR8Ijqy6tax3Hlt3ocoPNoYGPUMvbjv82tER5Oz7woI+KZRN45DHII71+OulWq6qEbqAfS3tw==";

ADD_A="\
zone ${ZONE}\n
update add HOSTNAME.${ZONE} 86400 A FORIP\n
send\n
zone RZONE.in-addr.arpa.\n
update delete REVIP.in-addr.arpa PTR\n
update add REVIP.in-addr.arpa 86400 PTR HOSTNAME.${ZONE}\n
send\n
"

REMOVE_A="\
zone ${ZONE}\n
update delete HOSTNAME.${ZONE} A\n
send\n
zone RZONE.in-addr.arpa.\n
update delete REVIP.in-addr.arpa PTR\n
send\n
"

ADD_CNAME="\
zone ${ZONE}\n
prereq nxdomain NICKNAME.${ZONE}\n
update add NICKNAME.${ZONE} 86400 CNAME HOSTNAME.${ZONE}\n
send\n
"

REMOVE_CNAME="\
zone ${ZONE}\n
update delete NICKNAME.${ZONE} CNAME\n
send\n
"

MKREVIP () {
	echo $1 | awk -F \. '{print $4"."$3"."$2"."$1}'
}

GETRZONE () {
	echo $1 | awk -F \. '{print $3"."$2"."$1}'
}

GETIP () {
	echo `host $1 | cut -d ' ' -f4`
}

ERROR () {
echo -e  "
usage : ddns add 	A 	{hostname} {ipaddress}
	ddns add 	CNAME 	{nickname} {hostname} 
	ddns remove 	A 	{hostname}
	ddns remove 	CNAME 	{nickname}\n"
}

case "$1" in 
	add )
		shift
		case "$1" in 
			A )
				shift
				if [ "$#" -ne 2 ] ; then  ERROR ; exit 1 ; fi
				hostName=$1
				ipAddress=$2

				revZone=`GETRZONE $ipAddress`
				revIP=`MKREVIP $ipAddress`

				echo -e  ${ADD_A} | \
				sed 	-e "s/HOSTNAME/$hostName/g" \
					-e "s/RZONE/$revZone/g" \
					-e "s/FORIP/$ipAddress/g" \
					-e "s/REVIP/$revIP/g" \
					> ${DDDATA}
			;;
			CNAME )
				shift
				if [ "$#" -ne 2 ] ; then  ERROR ; exit 1 ; fi
				hostName=$1
				refhostName=$2
				
				echo -e  ${ADD_CNAME} | \
				 sed 	-e "s/HOSTNAME/$refhostName/g" \
					-e "s/NICKNAME/$hostName/g" \
					> ${DDDATA}
			;;
			* ) 
				 ERROR; exit 1
			;; 
		esac
	;;

	remove )
		shift
		case "$1" in
			A )
				shift
				if [ "$#" -ne 1 ] ; then  ERROR ; exit 1 ; fi
				hostName=$1

				if !  host $hostName > /dev/null  
				then 
						echo  "Host $hostName does not exist!"
						exit 1
				fi

				ipAddress=`GETIP $hostName`

				revZone=`GETRZONE $ipAddress`
				revIP=`MKREVIP $ipAddress`

				echo -e ${REMOVE_A} | \
				sed 	-e "s/HOSTNAME/$hostName/g" \
					-e "s/RZONE/$revZone/g" \
					-e "s/REVIP/$revIP/g" \
					> ${DDDATA}
			;;
			CNAME )
				shift
				if [ "$#" -ne 1 ] ; then xx ERROR ; exit 1 ; fi
				hostName=$1

				if ! host $hostName > /dev/null  
                                        then 
                                                echo  "Host $hostName does not exist!"
                                                exit 1 
                                fi

				echo -e ${REMOVE_CNAME} | \
				sed 	-e "s/NICKNAME/$hostName/g" \
					> ${DDDATA}
			;;
			* )
				ERROR; exit 1
			;;
		esac
	;;

	* )
		ERROR ; exit 1 
	;;
esac

${NSUPDATE} -y ${RNDCKEY} ${DDDATA} 
if host $hostName > /dev/null
then
	echo "$hostName: `GETIP $hostName`"
fi
