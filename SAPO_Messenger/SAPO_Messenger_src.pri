CORE = ../core
PSI_CORE = $$CORE/psi-core
PSI_SRC = $$PSI_CORE/src
PSI_HELPERS = $$CORE/psi-helpers

include($$PSI_CORE/conf.pri)
include(../xcode_conf.pri)

MOC_DIR     = .moc
OBJECTS_DIR = .obj

system('echo "char *lfversion = \\"`cat ../VERSION`\\";" > $$CORE/lfversion.h')

INCLUDEPATH += ../platform $$CORE $$CORE/tools/appmain

HEADERS += \
	$$CORE/tools/appmain/appmain.h \
	$$CORE/tools/appmain/appplatform.h \
	$$PSI_SRC/capsmanager.h \
	$$PSI_SRC/capsregistry.h \
	$$PSI_SRC/capsspec.h \
	$$PSI_SRC/mucmanager.h \
	$$PSI_SRC/pixmaputil.h \
	$$PSI_HELPERS/avatars.h \
	$$PSI_HELPERS/filetransferhandler.h \
	$$PSI_HELPERS/jidutil.h \
	$$PSI_HELPERS/vcardfactory.h \
	$$CORE/sapo/audibles.h \
	$$CORE/sapo/liveupdate.h \
	$$CORE/sapo/chat_rooms_browser.h \
	$$CORE/sapo/chat_order.h \
	$$CORE/sapo/ping.h \
	$$CORE/sapo/server_items_info.h \
	$$CORE/sapo/sapo_agents.h \
	$$CORE/sapo/sapo_debug.h \
	$$CORE/sapo/sapo_photo.h \
	$$CORE/sapo/sapo_remote_options.h \
	$$CORE/sapo/server_vars.h \
	$$CORE/sapo/sms.h \
	$$CORE/sapo/transport_registration.h \
	$$CORE/account.h \
	$$CORE/lfp_call.h \
	$$CORE/lfp_api.h

SOURCES += \
	$$CORE/tools/appmain/appmain.cpp \
	$$PSI_SRC/capsmanager.cpp \
	$$PSI_SRC/capsregistry.cpp \
	$$PSI_SRC/capsspec.cpp \
	$$PSI_SRC/mucmanager.cpp \
	$$PSI_SRC/pixmaputil.cpp \
	$$PSI_HELPERS/avatars.cpp \
	$$PSI_HELPERS/filetransferhandler.cpp \
	$$PSI_HELPERS/jidutil.cpp \
	$$PSI_HELPERS/vcardfactory.cpp \
	$$CORE/sapo/audibles.cpp \
	$$CORE/sapo/liveupdate.cpp \
	$$CORE/sapo/chat_rooms_browser.cpp \
	$$CORE/sapo/chat_order.cpp \
	$$CORE/sapo/ping.cpp \
	$$CORE/sapo/server_items_info.cpp \
	$$CORE/sapo/sapo_agents.cpp \
	$$CORE/sapo/sapo_debug.cpp \
	$$CORE/sapo/sapo_photo.cpp \
	$$CORE/sapo/sapo_remote_options.cpp \
	$$CORE/sapo/server_vars.cpp \
	$$CORE/sapo/sms.cpp \
	$$CORE/sapo/transport_registration.cpp \
	$$CORE/account.cpp \
	$$CORE/lfp_call.cpp \
	$$CORE/lfp_api.cpp \
	$$CORE/main.cpp

# lilypad
mac:{
	QMAKE_INFO_PLIST = $$BUILD_DIR/Info.plist
	BUNDLE_NAME = SAPO_Messenger.app
	SOURCES += $$CORE/platform_mac.cpp
	LIBS += $$BUNDLE_NAME/Contents/MacOS/Lilypad.dylib
	QMAKE_LFLAGS_SHAPP += -F../lilypad/Frameworks -framework Growl -framework Sparkle
	mytarget.commands = \
		cp $$BUILD_DIR/Info.plist $$BUNDLE_NAME/Contents && \
		mkdir -p $$BUNDLE_NAME/Contents/Resources && \
		mkdir -p $$BUNDLE_NAME/Contents/MacOS && \
		mkdir -p $$BUNDLE_NAME/Contents/Frameworks && \
		cp -r $$BUILD_DIR/Resources $$BUNDLE_NAME/Contents/ && \
		cp $$BUILD_DIR/Lilypad.dylib $$BUNDLE_NAME/Contents/MacOS/ && \
		cp $$BUILD_DIR/MessageCenter*.mom $$BUNDLE_NAME/Contents/Resources/
	QMAKE_EXTRA_TARGETS += mytarget
	PRE_TARGETDEPS += mytarget
}
unix:!mac:{
	# null ui
	SOURCES += $$PSI_CORE/tools/appmain/atest_platform.cpp $$CORE/frog_null.cpp
}
