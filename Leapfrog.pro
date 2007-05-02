TEMPLATE = subdirs
CONFIG += ordered

PSI_CORE = core/psi-core

include($$PSI_CORE/conf.pri)
include(xcode_conf.pri)

jingle {
	SUBDIRS += $$PSI_CORE/third-party/libjingle
}

qca-static {
	SUBDIRS += $$PSI_CORE/third-party/qca
}

# This one builds the final app bundle
SUBDIRS += SAPO_Messenger
