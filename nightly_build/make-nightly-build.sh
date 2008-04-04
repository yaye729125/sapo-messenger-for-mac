#!/bin/sh

SVN_TRUNK_URL='svn://svn.softwarelivre.sapo.pt/sapo_msg_mac/trunk'

SRC_DIR='leapfrog-nightly-trunk'
PROJ_SUBDIR='lilypad'
PRODUCTS_SUBDIR='SAPO_Messenger'

BUILDS_DIR='nightly_builds_server_mirror'
APPCAST_FEED_FILENAME='appcast_feed.xml'

DSYMS_DIR='nightly_builds_dsyms'

APPCAST_FEED_SNIPPETS_DIR='appcast_feed_snippets'
LOGS_XSLT_STYLESHEET='svnlog2html.xsl'

MAX_NR_BUILDS_TO_KEEP=5

NIGHTLIES_SERVER_DIR='nightly_builds'
URL_PREFIX="http://messenger.sapo.pt/software_update/mac/${NIGHTLIES_SERVER_DIR}"


####################################
#  . Useful functions

BASE_DIR=`pwd`

function list_sorted_available_build_nrs {
	ls "${BASE_DIR}/${BUILDS_DIR}"/*.zip | sed 's/.*_\([0-9]*\).zip/\1/' | sort -rn
}


####################################
# 1. Make a new build

echo
echo "==================================================================="
date
echo

set -x

export PATH=$PATH:/usr/local/bin


if [ ! -d "$SRC_DIR" ]; then
    svn co "$SVN_TRUNK_URL" "$SRC_DIR"
else
    svn update "$SRC_DIR"
fi


# Take only the largest version number, stripping out an 'M' char that may exist at the end
REVISION=`svnversion "$SRC_DIR" | sed -E 's/([0-9]+:)?([0-9]+)(M|S)?/\2/'`
BUILD_NR=$(( $REVISION + 500 ))

PREV_BUILD_NR=`list_sorted_available_build_nrs | head -1`
PREV_REVISION=$(( ${PREV_BUILD_NR:=$(( $BUILD_NR - 1 ))} - 500 ))


cd "$SRC_DIR" || exit 1

# clean up
make clean || rm -fR .moc .obj
rm -fR Makefile xcode_conf.pri "$PRODUCTS_SUBDIR/Makefile" "$PRODUCTS_SUBDIR/SAPO_Messenger.app" "$PRODUCTS_SUBDIR/SAPO Messenger.app"


NEW_APP_ARCHIVE_FILENAME="SAPO_Messenger-build_${BUILD_NR}.zip"
NEW_APP_ARCHIVE_PATHNAME="../${BUILDS_DIR}/${NEW_APP_ARCHIVE_FILENAME}"
NEW_DSYM_ARCHIVE_FILENAME="SAPO_Messenger.dSYM-build_${BUILD_NR}.zip"
NEW_DSYM_ARCHIVE_PATHNAME="../${DSYMS_DIR}/${NEW_DSYM_ARCHIVE_FILENAME}"

if [ "$REVISION" -a ! -f "$NEW_APP_ARCHIVE_PATHNAME" ]; then
	
	cd "$PROJ_SUBDIR"
	xcodebuild	-project Lilypad.xcodeproj \
				-target Leapfrog \
				-configuration Release \
				clean build || exit 1
	cd ..
	
	
	if [ -d "$PRODUCTS_SUBDIR/SAPO Messenger.app" ]; then
		mkdir -p "../$BUILDS_DIR"
		
		# Create a ZIP archive using ditto to preserve resource forks
		ditto -V -c -k --keepParent "$PRODUCTS_SUBDIR/SAPO Messenger.app" "$NEW_APP_ARCHIVE_PATHNAME"
		
		# Also save a ZIP archive of the corresponding dSYM bundle for this build
		if [ -d "$PRODUCTS_SUBDIR/SAPO_Messenger.dSYM" ]; then
			mkdir -p "../$DSYMS_DIR"
			ditto -V -c -k --keepParent "$PRODUCTS_SUBDIR/SAPO_Messenger.dSYM" "$NEW_DSYM_ARCHIVE_PATHNAME"
		fi
	else
		# xcodebuild didn't fail, but mysteriously we ended up with no app bundle either
		exit 1
	fi
else
	# No new revision, just bail out.
	exit 0
fi

cd ..


####################################
# 2. Generate the appcast description for this new build

SNIPPET_XML_FILENAME="${BUILD_NR}_svnlog.xml"
SNIPPET_HTML_FILENAME="${BUILD_NR}_description.html"

mkdir -p "$APPCAST_FEED_SNIPPETS_DIR"
cd "$APPCAST_FEED_SNIPPETS_DIR"

OLDEST_AVAIL_BUILD_NR=`list_sorted_available_build_nrs | tail -1`
OLDEST_AVAIL_REVISION=$(( ${OLDEST_AVAIL_BUILD_NR:=$PREV_BUILD_NR} - 500 ))

svn log --xml -r ${REVISION}:${OLDEST_AVAIL_REVISION} "../$SRC_DIR" > "$SNIPPET_XML_FILENAME"
xsltproc "../$LOGS_XSLT_STYLESHEET" "$SNIPPET_XML_FILENAME" |
  ../convert_to_links.pl > "$SNIPPET_HTML_FILENAME"

cd ..


####################################
# 3. Clean up old files

for B in `list_sorted_available_build_nrs | tail +$(( $MAX_NR_BUILDS_TO_KEEP + 1 ))`; do
	rm -f "${BUILDS_DIR}/SAPO_Messenger-build_${B}.zip"
	rm -f "${APPCAST_FEED_SNIPPETS_DIR}/${B}_description.html"
	rm -f "${APPCAST_FEED_SNIPPETS_DIR}/${B}_svnlog.xml"
done


####################################
# 4. Re-generate the appcast feed

cat > "${BUILDS_DIR}/${APPCAST_FEED_FILENAME}" <<ENDOFHEAD
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"> 
    <channel>
        <title>SAPO Messenger Mac Appcast - Nightly Builds</title>
        <link>http://messenger.sapo.pt</link>
        <description>Most recent changes with links to updates.</description>
        <language>en</language>
		
ENDOFHEAD

for B in `list_sorted_available_build_nrs`; do
	{	echo '<item>'
		echo "    <title>Nightly Build ${B}</title>"
    echo '    <description><![CDATA['
		
		cat "${APPCAST_FEED_SNIPPETS_DIR}/${B}_description.html"
		
		FILE_NAME="SAPO_Messenger-build_${B}.zip"
		FILE_MOD_DATE=`stat -f '%Sm' "${BUILDS_DIR}/${FILE_NAME}"`
		FILE_SIZE=`stat -f '%z' "${BUILDS_DIR}/${FILE_NAME}"`
		FILE_URL="${URL_PREFIX}/${FILE_NAME}"
		
		echo '    ]]></description>'
		echo "    <pubDate>${FILE_MOD_DATE}</pubDate>"
		echo "    <enclosure url=\"${FILE_URL}\" sparkle:version=\"${B}\" sparkle:shortVersionString=\"1.0\" length=\"${FILE_SIZE}\" type=\"application/octet-stream\"/>"
		echo "    <link>${FILE_URL}</link>"
		echo '</item>'
		echo
				} >> "${BUILDS_DIR}/${APPCAST_FEED_FILENAME}"
done

cat >> "${BUILDS_DIR}/${APPCAST_FEED_FILENAME}" <<ENDOFTOE
    </channel>
</rss>
ENDOFTOE


####################################
# 5. Rsync with the server

./sync-nightly-builds-with-server.sh
