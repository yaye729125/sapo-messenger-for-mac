--------------------------------------------------
Where's the code?
--------------------------------------------------

Official project Trac web-site:
    * http://trac.softwarelivre.sapo.pt/sapo_msg_mac

Official Subversion repository:
    * svn://svn.softwarelivre.sapo.pt/sapo_msg_mac


--------------------------------------------------
Dependencies
--------------------------------------------------

In order to build SAPO Messenger from this source code release you will need to have the Qt development toolkit from Trolltech installed on your system. You can get it from <http://www.trolltech.com/products/qt>. In order to end up with a completely self-contained SAPO Messenger application bundle (like the one distributed by Sapo in binary form at <http://messenger.sapo.pt>), you'll need to have Qt built as a set of Universal dynamic libraries (dylibs) instead of as framework bundles (which is Qt's default). The scripts that build SAPO Messenger are counting on Qt dylibs being available to copy them into the final app bundle.

The following command line lists a good base set of parameters you should pass to Qt's "configure" script:

    $ ./configure -qt-gif -no-cups -no-framework -universal


--------------------------------------------------
Building
--------------------------------------------------

The easiest way to build SAPO Messenger is probably by using the terminal. After issuing the following commands on your shell, and if everything goes as planned, you'll get a new "SAPO Messenger.app" application bundle inside the "SAPO_Messenger" directory.

How to build a release:
    $ cd lilypad
    $ xcodebuild -configuration Release -target Leapfrog
	(The resulting application bundle will be in ../SAPO_Messenger)

Alternatively, if you know your way around Xcode, you may open the Lilypad.xcode proj project file and build it right from there. Make sure to select the "Release" build configuration and the "Leapfrog" target to get the same result as you'd get from building the app from a terminal shell with the above commands.
