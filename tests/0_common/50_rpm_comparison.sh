#!/bin/bash

# v0.0.1 - Apr 16 2021 - Initial version by Rich Alloway <ralloway@perforce.com>

t_Log "Running $0 - RPM comparison test (PoC)"

t_InstallPackage wget sed diffutils yum-utils

# Set any necessary or desired wget options (default is empty)
WGETOPTS=""
 
# Set wget options for proxy
WGETOPTS="-e use_proxy=yes -e http_proxy=10.0.2.2:3128 -e https_proxy=10.0.2.2:3128"

# Upstream source repo that contains the binary RPMs
SRCREPO='http://mirror.centos.org/centos/8/BaseOS/x86_64/os/'
# The Rocky Linux repo that contains the binary RPMs
PUTREPO='http://rocky.lowend.ninja/RockyDevel/BaseOS_final/'

# Manually build the list of packages to compare
#PKGLIST=('sed')
#PKGLIST+=('glibc')
#PKGLIST+=('iptables-libs')
#PKGLIST+=('kernel')

# Build list of packages to compare by reading from PKGLIST.txt (1 pkg per line), located in the current working directory
PKGLIST=( $(cat PKGLIST.txt) )

[ "${#PKGLIST[@]}" == 0 ] && { t_Log "FAIL: package list is empty"; exit $FAIL; }

# Default to passing, if any RPM comparisons differ, this is set to 0
PASS=1

for index in ${!PKGLIST[@]}
do
	#t_Log "Comparing $(basename ${SRCLIST[$index]}) ..."
	t_Log "Comparing $(basename ${PKGLIST[$index]}) ..."

	# Clean tmp files from any previous iterations
	rm -f /tmp/src.rpm /tmp/put.rpm /tmp/src.rpm.tags /tmp/put.rpm.tags

	# Download the RPMs for comparison
	url=$(yumdownloader --arch=x86_64,noarch --disablerepo=* --repofrompath=SRC,$SRCREPO --url --quiet ${PKGLIST[$index]})
	wget $WGETOPTS -qO /tmp/src.rpm $url || { t_Log "FAIL: Unable to download upstream RPM"; exit $FAIL; }
	url=$(yumdownloader --arch=x86_64,noarch --disablerepo=* --repofrompath=PUT,$PUTREPO --url --quiet ${PKGLIST[$index]})
	wget $WGETOPTS -qO /tmp/put.rpm $url || { t_Log "FAIL: Unable to download upstream RPM"; exit $FAIL; }

	# List of tags to be queried and compared
	QF="nevra=%{NEVRA}\n"
	QF="${QF}[dirnames=%{DIRNAMES}\n]"
	QF="${QF}[file=%{FILENAMES} flags=%{FILEFLAGS} group=%{FILEGROUPNAME} username=%{FILEUSERNAME} linkto=%{FILELINKTOS} mode=%{FILEMODES}\n]"
	QF="${QF}encoding=%{ENCODING}\n"
	QF="${QF}[filerequire=%{FILEREQUIRE}\n]"
	QF="${QF}group=%{GROUP}\n"
	QF="${QF}license=%{LICENSE}\n"
	QF="${QF}prein=%{PREIN}\n"
	QF="${QF}preinprog=%{PREINPROG}\n"
	QF="${QF}pretrans=%{PRETRANS}\n"
	QF="${QF}pretransprog=%{PRETRANSPROG}\n"
	QF="${QF}preun=%{PREUN}\n"
	QF="${QF}preunprog=%{PREUNPROG}\n"
	QF="${QF}postin=%{POSTIN}\n"
	QF="${QF}postinprog=%{POSTINPROG}\n"
	QF="${QF}posttrans=%{POSTTRANS}\n"
	QF="${QF}posttransprog=%{POSTTRANSPROG}\n"
	QF="${QF}postun=%{POSTUN}\n"
	QF="${QF}postunprog=%{POSTUNPROG}\n"
	QF="${QF}[provides=%{PROVIDENEVRS}\n]"
	QF="${QF}[requires=%{REQUIRENEVRS}\n]"
	QF="${QF}srcrpm=%{SOURCERPM}\n"

	# Query and store RPM tags
	rpm -qp --queryformat="$QF" /tmp/src.rpm > /tmp/src.rpm.tags
	rpm -qp --queryformat="$QF" /tmp/put.rpm > /tmp/put.rpm.tags

	# Verify that VENDOR and PACKAGER tags are present (were missing during mock builds)
	rpm -qp --queryformat="vendor=%{VENDOR}\npackager=%{PACKAGER}\n" /tmp/put.rpm | grep -q "(none)" && { t_Log "WARN: Rocky Linux RPM missing VENDOR and/or PACKAGER tags"; }

	# Clean out build-related dirs/files which are expected to change and empty tags
	sed -e 's/^\(.*\)\.build-id.*$/\1<ignored>/g' /tmp/src.rpm.tags | grep -Ev '<ignored>|=$' > /tmp/rpm.tags; mv /tmp/rpm.tags /tmp/src.rpm.tags 
	sed -e 's/^\(.*\)\.build-id.*$/\1<ignored>/g' /tmp/put.rpm.tags | grep -Ev '<ignored>|=$' > /tmp/rpm.tags; mv /tmp/rpm.tags /tmp/put.rpm.tags

	# Run pkgdiff to see if this method is better suited to compare packages in release testing
	#pkgdiff /tmp/src.rpm /tmp/put.rpm

	# If there are differences between the tags, there may be a problem
	diff -u0 -w /tmp/src.rpm.tags /tmp/put.rpm.tags 
	ret_val=$?
	#[ "$ret_val" == 0 ] || { t_Log "FAIL: upstream and Rocky Linux RPM for $(basename ${PKGLIST[$index]}) differ"; exit $FAIL; }
	[ "$ret_val" == 0 ] || { t_Log "FAIL: upstream and Rocky Linux RPM for $(basename ${PKGLIST[$index]}) differ"; PASS=0; }
	[ "$ret_val" == 0 ] && { t_Log "PASS: upstream and Rocky Linux RPM for $(basename ${PKGLIST[$index]}) match"; }

	# If any compares showed a difference, our last iteration of this loop will have a non-zero exist status, 
	# triggering t_CheckExitStatus to fail the test
	[ $PASS != 1 ] && false
done

# Check for a 0 exit status
t_CheckExitStatus $?
