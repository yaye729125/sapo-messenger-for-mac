#!/bin/sh
cd ../SAPO_Messenger.app
find . -name '.svn' -exec rm -fR {} \; -prune

cd ..
rm -fR "SAPO Messenger.app"
mv SAPO_Messenger.app/Contents/MacOS/SAPO_Messenger "SAPO_Messenger.app/Contents/MacOS/SAPO Messenger"
mv SAPO_Messenger.app "SAPO Messenger.app"

# Disable the English localization by default
mkdir -p "SAPO Messenger.app/Contents/Resources Disabled"
mv -f "SAPO Messenger.app/Contents/Resources/English.lproj" "SAPO Messenger.app/Contents/Resources Disabled"

