#!/usr/bin/bash


# Remember! Lock file is removed when one of the scripts exits and it is
#           the only script holding the lock or lock is not acquired at all.

if (( $# > 0 )); then
	echo "checkupdates: Safely print a list of pending updates."
	echo "Use: checkupdates"
	echo "Export the 'CHECKUPDATES_DB' variable to change the path of the temporary database."
	exit 0
fi

if [[ -z $CHECKUPDATES_DB ]]; then
	CHECKUPDATES_DB="${TMPDIR:-/tmp}/checkup-db-${USER}/"
fi

# Lockable script boilerplate

### HEADER ###

LOCKFILE="$CHECKUPDATES_DB/checker.lck"
LOCKFD=99

# PRIVATE
_lock()             { flock -$1 $LOCKFD; }
_no_more_locking()  { 
	finish=1;
	rm -f $CHECKUPDATES_DB/db.lck;
	_lock u; _lock xn && rm -f $LOCKFILE; }
_prepare_locking()  { eval "exec $LOCKFD>\"$LOCKFILE\""; trap _no_more_locking INT TERM EXIT; }

# ON START
_prepare_locking

# PUBLIC
exlock_now()        { _lock xn; }  # obtain an exclusive lock immediately or fail
exlock()            { _lock x; }   # obtain an exclusive lock
shlock()            { _lock s; }   # obtain a shared lock
unlock()            { _lock u; }   # drop a lock

### BEGIN OF SCRIPT ###

# Simplest example is avoiding running multiple instances of script.
exlock_now || exit 1

DBPath="${DBPath:-/var/lib/pacman/}"
eval $(awk -F' *= *' '$1 ~ /DBPath/ { print $1 "=" $2 }' /etc/pacman.conf)

mkdir -p "$CHECKUPDATES_DB"
ln -s "${DBPath}/local" "$CHECKUPDATES_DB" &> /dev/null

while (( finish != 1 )); do
	echo -n "" > "${CHECKUPDATES_DB}/updates.log"
	fakeroot pacman -Sy --dbpath "$CHECKUPDATES_DB" --logfile /dev/null &> /dev/null
	pacman -Qqu --dbpath "$CHECKUPDATES_DB" 2> /dev/null | while read -r package; do
		oldver=`pacman -Q --dbpath "$CHECKUPDATES_DB" "$package" | awk '{print $2}'`
		newver=`pacman -Sdp --print-format "%v" --dbpath "$CHECKUPDATES_DB" "$package"`
		echo "$package $oldver -> $newver" >> "${CHECKUPDATES_DB}/updates.log"
	done

	echo 'updatePacWidget()' | awesome-client

	sleep 3600 # in seconds
done
exit 0

# vim: set ts=2 sw=2 noet:
