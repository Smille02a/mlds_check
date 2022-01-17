#!/bin/ksh
##################################################################
#
#       Archive Store and Arrival Script
#       /usr/local/admin/bin/Env_check.R2.ksh
#
#       Created:   09/18/95
#       Modified:  09/25/95
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
if `mkdir $host >> $LOGFILE 2>&1`; then
	print "\n`date`\n\tCreated $BASE_RUN/${host}"
else
	print "\n`date`\n\tCouldnt create  $BASE_RUN/${host}"
	print "\tAborting..."
	exit 1
fi
cd $host
#if `rsh $host uname -r |read RARCH >> $LOGFILE 2>&1`; then
rsh $host uname -r |read RARCH >> $LOGFILE 2>&1
print "\t$host OS is $RARCH"
#
if [[ "$RARCH" = "5.4" || "$RARCH" = "5.3" ]]; then
	RARCH="Solaris"
	print "\t$host is a $RARCH machine"
else
	RARCH="SunOS"
	print "\t$host is a $RARCH machine"
fi
if [[ "$RARCH" = "Solaris" ]]; then
	if `rsh $host ps -ef  > $host.pstat `; then
		print "\tSuccessfully captured ps table"
	else
		print "\tError exited during ps capture"
	fi
elif  [[ "$RARCH" = "SunOS" ]]; then
	if `rsh $host ps -auwx  > $host.pstat `; then
		print "\tSuccessfully captured ps table"
	else
		print "\tError exited during ps capture"
	fi
fi
if `rsh $host /usr/local/admin/scr/partchk.ksh `; then
	print "\tSuccessfully ran remote partchk"
else
	print "\tError exited during partchk"
fi
if `rsh $host tar cf - -C / etc | tar xf - `; then
	print "\tSuccessfully copied /etc files"
else
	 print "\tError exited during /etc file copy"
fi
if [[ "`rsh $host ypwhich -m |head -1 |cut  -d' ' -f2,5`" = "$host" ]];
then
	print "\t$host is an NIS master, copying yp files"
	if `rsh $host tar cf - -C /var/yp maps |tar xf - `; then
		print "\tSuccessfully copied  /var/yp files"
	else
		print "\ttError exited during yp copy"
	fi
fi
if `rsh $host /usr/local/bin/sysinfo > $host.sysinfo `; then
	print "\tSuccessfully captured sysinfo"
else
	print "\tError exited during sysinfo"
fi
rcp "${host}:/tmp/*${DATE}.log" .
if `find . -type f -exec $COMPRESS  {} \; >> $LOGFILE 2>&1`;  then
	print "\tSuccessfully Completed Compress stage"
else
	print "\tError exited during $COMPRESS"
fi
}
#
##################################################################
## MAIN
##################################################################
#
VERSION="/usr/local/admin/bin/Env_check.R2.ksh"
NIS_HOSTS=`/usr/local/bin/listgroup spspme sps spsprod spsprodw sisprod sisdev pmedev`
OTHER_HOSTS=""
HOSTS="$NIS_HOSTS $OTHER_HOSTS"
WHO=`/usr/ucb/whoami`
DATE=`date +%m%d%y`
HOST=`uname -n`
ARCH=`uname -r` 
MAIL_LIST="sysdoc"
BASE_DIR="/usr/local/admin/data"
BASE_RUN="$BASE_DIR/$DATE"
LOGFILE="/tmp/Env_check_$DATE.log"
TMPFILE="/tmp/Env_check_$DATE.tmp"
ERRLOG="/tmp/Env_check_$DATE.err"
BEEP="/usr/local/bin/beep"
COMPRESS="/opt/gnu/bin/gzip -fqr"
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
print "\n\nThis following hosts will be checked\n$HOSTS\n\n"  >> $LOGFILE
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
cd $BASE_DIR
print "\n`date`\n\t$HOST: Checking for data archives to Remove" >> $LOGFILE
for ENTRY in `ls -t |awk 'NR>5 {print $0}'`
do
	/bin/rm -fr ${ENTRY} >> $LOGFILE 2>&1
	print "\tRemoving $BASE_DIR/${ENTRY} archive" >> $LOGFILE
done
#
for host in $NIS_HOSTS
do
if `ping $host  >> /dev/null 2>&1`; then
  if `rsh $host ls  >> /dev/null 2>&1`; then
     if `get_info >> $LOGFILE 2>&1`; then
	status="success"
     else
	status="failure"
     fi
  else
     print "\n`date`\n\t$host has no Equivalency from $HOST"  >> $LOGFILE
     echo "Root from $HOST has no Equivalency to $host " |/usr/ucb/mail \
	-s "Root to $host from $HOST has no Equivalency" sysdoc
  fi
else
  print "\n`date`\n\t$host is not currently pingable...  skipping"  >> $LOGFILE
fi
done
cat $LOGFILE |/usr/ucb/mail -s "SPS / PME ENVIRONMENT STATS" sysdoc
#
##################################################################
## DONE
##################################################################
