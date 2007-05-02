#!/bin/sh
cd ..

PATH=$PATH:/usr/bin:/usr/local/bin
export PATH

# Substitute tokens in Info.plist
REV=`svnversion -n . | sed 's/\(.*:\)\{0,1\}\([[:digit:]]*\).*/\2/'`
VER=`cat VERSION`
INFOPLIST="$BUILT_PRODUCTS_DIR/Info.plist"

cat "$PROJECT_DIR/$INFOPLIST_FILE" \
	| sed "s/@VERSION@/$VER/" \
	| sed "s/@REVISION@/$REV/" \
	> "$INFOPLIST"

# Generate conf.pri for qmake
CONF_FILE=conf.pri
CONF_FILE_TMP=conf.pri_tmp

if echo "$BUILD_STYLE" | grep -q "^Release"; then
	CONFIG_ADD="release x86 ppc"
	CONFIG_REM=debug
else
	CONFIG_ADD="debug $NATIVE_ARCH"
	CONFIG_REM=release
fi

rm -f $CONF_FILE_TMP
echo "CONFIG += $CONFIG_ADD" >> $CONF_FILE_TMP
echo "CONFIG -= $CONFIG_REM" >> $CONF_FILE_TMP
echo "QMAKE_CFLAGS += $OPTIMIZATION_CFLAGS" >> $CONF_FILE_TMP
echo "QMAKE_CXXFLAGS += $OPTIMIZATION_CFLAGS" >> $CONF_FILE_TMP
echo "BUILD_DIR = ${BUILT_PRODUCTS_DIR}" >> $CONF_FILE_TMP

if [ "$GCC_GENERATE_DEBUGGING_SYMBOLS" = "YES" ]; then
	# Force the debug flags in if we have that option checked in Xcode. This is useful for
	# making a "release" build with debug symbols, which can then be used to decode addresses
	# from crash logs sent by the users (with the help of the "atos" command-line tool).
	echo "QMAKE_CFLAGS += -g -gdwarf-2" >> $CONF_FILE_TMP
	echo "QMAKE_CXXFLAGS += -g -gdwarf-2" >> $CONF_FILE_TMP
fi


# Only overwrite the CONF_FILE if it is different from the previous version. This will prevent
# "make" from forcing the rebuild of the app everytime, even if there are no changes to the code.
if [ -f $CONF_FILE ] && diff $CONF_FILE_TMP $CONF_FILE; then
    rm -f $CONF_FILE_TMP
else
    mv -f $CONF_FILE_TMP $CONF_FILE
fi

#if [ "$CONFIGURATION" = "Release" ]; then
#	echo "POSTFLIGHT = ./finalize" >> $CONF_FILE
#fi

