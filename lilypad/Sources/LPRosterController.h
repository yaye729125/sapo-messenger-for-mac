//
//  LPRosterController.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jpavao@co.sapo.pt>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//
//
// Manages the roster window.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


typedef enum {
	LPRosterSortByAvailability,
	LPRosterSortByName
} LPRosterSortOrder;


@class LPContact, LPRoster, LPAccount;
@class JKGroupTableView;
@class LPAvatarButton;
@class LPAddContactController, LPEditGroupsController;
@class LPAccountNameTextField;
@class JKAnimatedGroupTableView;
@class LPColorBackgroundView;
@class LPStatusMenuController;
@class LPPubManager;
@class LPRosterEventsBadgeView;


@interface LPRosterController : NSWindowController 
{
	// General Window Structure
	IBOutlet NSView						*m_rosterElementsContentView;
	IBOutlet NSView						*m_pubElementsContentView;
	
	IBOutlet JKAnimatedGroupTableView	*m_rosterTableView;
	IBOutlet LPAvatarButton				*m_avatarButton;
	IBOutlet LPAccountNameTextField		*m_fullNameField;
	IBOutlet LPRosterEventsBadgeView	*m_eventsBadgeImageView;
	IBOutlet NSPopUpButton				*m_statusButton;
	IBOutlet NSButton					*m_infoButton;
	IBOutlet NSSearchField				*m_searchField;
	IBOutlet LPColorBackgroundView		*m_smsCreditBackground;
	IBOutlet NSTextField				*m_smsCreditTextField;
	IBOutlet NSTextField				*m_statusMessageTextField;
	IBOutlet WebView					*m_pubBannerWebView;
	IBOutlet WebView					*m_pubStatusWebView;
	
	IBOutlet NSMenu						*m_groupContextMenu;
	IBOutlet NSMenu						*m_contactContextMenu;
	IBOutlet NSMenu						*m_groupsListMenu;
	IBOutlet NSMenu						*m_groupChatsListInContactMenu;
	IBOutlet NSMenu						*m_groupChatsListInGroupMenu;
	IBOutlet NSMenu						*m_statusMsgURLsListMenu;
	
	IBOutlet NSObjectController			*m_accountController;
	
	IBOutlet NSWindow					*m_groupNameSheet;
	IBOutlet NSTextField				*m_groupNameSheetTextField;
	
	id						m_delegate;
	
	LPRoster				*m_roster;
	NSMutableArray			*m_flatRoster;
	
	BOOL					m_showOfflineContacts;
	BOOL					m_showGroups;
	BOOL					m_listGroupsBesideContacts;
	BOOL					m_useSmallRowHeight;
	LPRosterSortOrder		m_currentSortOrder;
	int						m_currentSearchCategoryTag;
	
	NSArray					*m_sortDescriptors;
	
	LPAddContactController	*m_addContactController;
	LPEditGroupsController	*m_editGroupsController;
	
	// Group menus that we need to update
	NSMutableArray			*m_groupMenus;
	
	LPPubManager			*m_currentPubManager;
}

- initWithRoster:(LPRoster *)roster delegate:(id)delegate;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (LPRoster *)roster;

- (void)setNeedsToUpdateRoster:(BOOL)flag;

- (void)addGroupMenu:(NSMenu *)menu;
- (void)removeGroupMenu:(NSMenu *)menu;
- (void)updateGroupMenu:(NSMenu *)menu;
- (void)updateAllGroupMenus;

- (void)updateGroupChatsMenu:(NSMenu *)menu settingMenuItemAction:(SEL)action;
- (void)updateStatusMessageURLsMenu:(NSMenu *)menu;

- (void)interactiveRemoveContacts:(NSArray *)contacts;
- (void)interactiveRemoveContactsAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)interactiveRemoveGroups:(NSArray *)groups;
- (void)interactiveRemoveGroups:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)setStatusMessage;

// Methods for changing properties of the events badge
- (BOOL)hasDebuggerBadge;
- (void)setHasDebuggerBadge:(BOOL)flag;
- (int)badgedUnreadOfflineMessagesCount;
- (void)setBadgedUnreadOfflineMessagesCount:(int)count;
- (int)badgedCountOfPresenceSubscriptionsRequiringAttention;
- (void)setBadgedCountOfPresenceSubscriptionsRequiringAttention:(int)count;
- (int)badgedPendingFileTransfersCount;
- (void)setBadgedPendingFileTransfersCount:(int)count;

- (NSMenu *)eventsBadgeMenu;
- (void)setEventsBadgeMenu:(NSMenu *)menu;

- (IBAction)addContactButtonClicked:(id)sender;
- (IBAction)addContactMenuItemChosen:(id)sender;
- (IBAction)removeContacts:(id)sender;
- (IBAction)editContact:(id)sender;
- (IBAction)editGroups:(id)sender;
- (IBAction)removeContactsFromCurrentGroup:(id)sender;
- (IBAction)moveContactsToGroup:(id)sender;
- (IBAction)moveContactsToNewGroup:(id)sender;
- (IBAction)startChatOrSMS:(id)sender;
- (IBAction)startChat:(id)sender;
- (IBAction)startGroupChat:(id)sender;
- (IBAction)startGroupChatWithGroup:(id)sender;
- (IBAction)inviteContactToGroupChatMenuItemChosen:(id)sender;
- (IBAction)inviteGroupToGroupChatMenuItemChosen:(id)sender;
- (IBAction)sendSMS:(id)sender;
- (IBAction)sendSMSToGroup:(id)sender;	// only for the group context menu
- (IBAction)sendFile:(id)sender;

// These are only connected to from the contextual menus, since you can't select a group row in the roster
- (IBAction)renameGroup:(id)sender;
- (IBAction)renameGroupOKClicked:(id)sender;
- (IBAction)renameGroupCancelClicked:(id)sender;
- (IBAction)deleteGroup:(id)sender;

- (IBAction)toggleShowOfflineBuddies:(id)sender;
- (IBAction)toggleShowGroups:(id)sender;
- (IBAction)toggleListGroupsBesideContacts:(id)sender;
- (IBAction)toggleUseSmallRowHeight:(id)sender;
- (IBAction)sortByAvailability:(id)sender;
- (IBAction)sortByName:(id)sender;

- (IBAction)performFindPanelAction:(id)sender;  // for activating the search text field on cmd-F
- (IBAction)contactFilterStringDidChange:(id)sender;
- (IBAction)changeSearchScope:(id)sender;

- (IBAction)copyStatusMessage:(id)sender;
- (IBAction)copyURLMenuItemChosen:(id)sender;
- (IBAction)openURLMenuItemChosen:(id)sender;

@end


@interface NSObject (LPRosterControllerDelegate)
- (void)rosterController:(LPRosterController *)rosterCtrl openChatWithContact:(LPContact *)contact;
- (void)rosterController:(LPRosterController *)rosterCtrl openGroupChatWithContacts:(NSArray *)contacts;
- (void)rosterController:(LPRosterController *)rosterCtrl sendSMSToContacts:(NSArray *)contacts;
- (void)rosterController:(LPRosterController *)rosterCtrl editContacts:(NSArray *)contacts;
- (void)rosterController:(LPRosterController *)rosterCtrl importAvatarFromPasteboard:(NSPasteboard *)pboard;
- (LPStatusMenuController *)rosterControllerGlobalStatusMenuController:(LPRosterController *)rosterCtrl;
- (LPStatusMenuController *)rosterController:(LPRosterController *)rosterCtrl statusMenuControllerForAccount:(LPAccount *)account;
@end

