CORE = ../core
PSI_CORE = $$CORE/psi-core

include($$PSI_CORE/conf.pri)
include(../xcode_conf.pri)

CONFIG  += qt thread
QT		+= network xml qt3support
DEFINES += QT_STATICPLUGIN


# IPv6 ?
#DEFINES += NO_NDNS


# cutestuff
include($$PSI_CORE/cutestuff/cutestuff.pri)

# tools
include($$PSI_CORE/src/tools/iconset/iconset.pri)
include($$PSI_CORE/src/tools/zip/zip.pri)

# qca
qca-static {
	# QCA
	DEFINES += QCA_STATIC
	QCA_CPP = $$PSI_CORE/third-party/qca
	INCLUDEPATH += $$QCA_CPP/include/QtCrypto
	LIBS += -L$$QCA_CPP -lqca_psi
	windows:LIBS += -lcrypt32
	mac:LIBS += -framework Security

	# QCA-OpenSSL
	contains(DEFINES, HAVE_OPENSSL) {
		include($$PSI_CORE/third-party/qca-openssl.pri)
	}
	
	# QCA-SASL
	contains(DEFINES, HAVE_CYRUSSASL) {
		include($$PSI_CORE/third-party/qca-sasl.pri)
	}

	# QCA-GnuPG
	include($$PSI_CORE/third-party/qca-gnupg.pri)
}
else {
	CONFIG += crypto	
}

# Google FT
google_ft {
	DEFINES += GOOGLE_FT
	HEADERS += $$PSI_CORE/src/googleftmanager.h
	SOURCES += $$PSI_CORE/src/googleftmanager.cpp
	include($$PSI_CORE/third-party/libjingle.new/libjingle.pri)
}

# Jingle
jingle {
	HEADERS += $$PSI_CORE/src/jinglevoicecaller.h
	SOURCES += $$PSI_CORE/src/jinglevoicecaller.cpp
	DEFINES += HAVE_JINGLE POSIX

	JINGLE_CPP = $$PSI_CORE/third-party/libjingle
	LIBS += -L$$JINGLE_CPP -ljingle_psi
	INCLUDEPATH += $$JINGLE_CPP

	contains(DEFINES, HAVE_PORTAUDIO) {
		LIBS += -framework CoreAudio -framework AudioToolbox
	}
}

# include Iris XMPP library
include($$PSI_CORE/iris/iris.pri)


# Building the app bundle
include(SAPO_Messenger_src.pri)
