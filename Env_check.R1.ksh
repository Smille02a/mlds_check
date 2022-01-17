#!/bin/ksh
##################################################################
#
#       Archive Store and Arrival Script
#       /usr/local/bin/Env_check.R1.ksh
#
#       Created:   09/18/95
#       Modified:  09/18/95
#
#       Merrill Lynch
#       Stephen Miller, SA
#               Phone:  (212)
#               Beeper: (800) 225-0256 pin 95684
#               email:  smiller@ml.com
#
#       This file is designed to be run by cron as useo root
#	every morning at 0500.
#
#       It will email one report at 0530 to sysdoc
#
##################################################################
#
get_info()
{
cd $BASE_RUN
mkdir $host
cd $host
rsh $host tar cf - -C / etc | tar xvf -
if [[ "`rsh $host ypwhich -m |head -1 |cut  -d' ' -f2,5`" = "$host" ]];
then
	echo "$host is an NIS master"
	rsh $host tar cf - -C /var yp |tar xvf -
fi
 rsh $host /usr/local/bin/sysinfo > $host.sysinfo
rsh $host 'ps -auwwx' > $host.psstat
rsh $host /usr/local/admin/scr/partchk.ksh
rcp ${host}:/tmp/${host}_disk_info_${DATE}.log .
}
#
##################################################################
## MAIN
##################################################################
#
VERSION="/usr/local/admin/bin/Env_check.R1.ksh"
NIS_HOSTS=`/usr/local/bin/listgroup sisprod`
OTHER_HOSTS="goliath sparc10 stealth mlfire"
HOSTS="$NIS_HOSTS $OTHER_HOSTS"
WHO=`/usr/ucb/whoami`
DATE=`date +%m%d%y`
HOST=`uname -n`
MAIL_LIST="sysdoc"
BASE_DIR="/usr/local/admin/data"
BASE_RUN="$BASE_DIR/$DATE"
LOGFILE="/tmp/Env_check_$DATE.log"
TMPFILE="/tmp/Env_check_$DATE.tmp"
ERRLOG="/tmp/Env_check_$DATE.err"
pingfile="/tmp/pingfile"
BEEP="/usr/local/bin/beep"
#
if [[ "$WHO" != "root" ]]; then
    echo ""
    echo "You are not root.  Please su to root and run again"
    echo ""
    exit 1
fi
#
if [[ "$ARCH" = "5.4" || "$ARCH" = "5.3" ]]; then
        ARCH="Solaris"
else
        ARCH="SunOS"
fi
#
>$LOGFILE
#
print "\nThis logfile file has been created  on `date` "  >> $LOGFILE
print "\n\tHostname:    $HOST" >> $LOGFILE
print "\tScript name: $VERSION"  >> $LOGFILE
print "\tLog file:    $LOGFILE\n"  >> $LOGFILE
print "It depicts the environment of hosts" >> $LOGFILE
print "and availability of system resources. - SWM\n\n"  >> $LOGFILE
#
if [ ! -d $BASE_DIR ]; then
	print "\n`date`\n\t$HOST: $BASE_DIR must exist to run"
	exit 1
elif  [ ! -d $BASE_RUN ];then
	mkdir -p $BASE_RUN
else
	cd $BASE_DIR
	rm -fr $DATE
	mkdir -p $BASE_RUN
fi
#
for host in $NIS_HOSTS
do
if `ping $host  >> $LOGFILE 2>&1`; then
  if `rsh $host ls  >> /dev/null 2>&1`; then
     if `get_info >> $LOGFILE 2>&1`; then
	status="success"
     else
	status="failure"
     fi
  else
     print "\tRoot from $HOST has no Equivalency to $host" >> $LOGFILE
  fi
else
  print "\t$host is not currently pingable...  skipping"  >> $LOGFILE
fi
done
#
##################################################################
## DONE
##################################################################
