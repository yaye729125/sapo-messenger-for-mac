//
//  LPGroupChatController.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPGroupChatController.h"
#import "LPGroupChat.h"
#import "LPGroupChatContact.h"
#import "LPGroupChatConfigController.h"
#import "LPAccount.h"
#import "LPRoster.h"
#import "LPGroup.h"
#import "LPContact.h"
#import "LPContactEntry.h"
#import "LPChatViewsController.h"
#import "LPColorBackgroundView.h"
#import "LPGrowingTextField.h"
#import "LPRosterDragAndDrop.h"
#import "LPCapabilitiesPredicates.h"

#import "NSString+HTMLAdditions.h"
#import "NSxString+EmoticonAdditions.h"


#define INPUT_LINE_HISTORY_ITEMS_MAX	20


// KVO Contexts
static NSString *LPGroupChatContext					= @"GroupChatContext";
static NSString *LPGroupChatParticipantsContext		= @"ParticipantsContext";
static NSString *LPParticipantsAttribsContext		= @"PartAttributesContext";


// Toolbar item identifiers
static NSString *ToolbarSetTopicIdentifier		= @"SetTopic";
static NSString *ToolbarSetNicknameIdentifier	= @"SetNickname";
static NSString *ToolbarInviteIdentifier		= @"Invite";
static NSString *ToolbarPrivateChatIdentifier	= @"PrivateChat";
static NSString *ToolbarConfigRoomIdentifier	= @"ConfigRoom";


@implementation LPGroupChatParticipantsTableView

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	NSPoint mouseLocInView = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	int hitRow = [self rowAtPoint:mouseLocInView];
	
	if (hitRow < 0) {
		return nil;
	}
	else {
		[[self window] makeFirstResponder:self];
		
		if (![[self selectedRowIndexes] containsIndex:hitRow])
			[self selectRowIndexes:[NSIndexSet indexSetWithIndex:hitRow] byExtendingSelection:NO];
		
		return [self menu];
	}
}

@end


@interface LPGroupChatController ()  // Private Methods
- (void)p_startObservingGroupChatParticipants;
- (void)p_stopObservingGroupChatParticipants;
- (void)p_startObservingGroupChatParticipant:(LPGroupChatContact *)participant;
- (void)p_stopObservingGroupChatParticipant:(LPGroupChatContact *)participant;
- (void)p_setupChatDocumentTitle;
- (void)p_setSendFieldHidden:(BOOL)hideFlag animate:(BOOL)animateFlag;
- (void)p_fixResizeIndicator;
- (void)p_showRejoinOverlayWindowWithTitle:(NSString *)title message:(NSString *)message;
- (void)p_dismissOverlayWindow;
- (void)p_setupToolbar;
@end


@implementation LPGroupChatController

- initWithGroupChat:(LPGroupChat *)groupChat delegate:(id)delegate
{
	if (self = [self initWithWindowNibName:@"GroupChat"]) {
		m_delegate = delegate;
		
		m_groupChat = [groupChat retain];
		[m_groupChat setDelegate:self];
		
		NSUserDefaultsController *prefsCtrl = [NSUserDefaultsController sharedUserDefaultsController];
		
		[m_groupChat addObserver:self forKeyPath:@"active" options:0 context:LPGroupChatContext];
		[m_groupChat addObserver:self forKeyPath:@"nickname" options:0 context:LPGroupChatContext];
		[m_groupChat addObserver:self forKeyPath:@"myGroupChatContact" options:0 context:LPGroupChatContext];
		[m_groupChat addObserver:self forKeyPath:@"myGroupChatContact.affiliation" options:0 context:LPGroupChatContext];
		[prefsCtrl addObserver:self forKeyPath:@"values.DisplayEmoticonImages" options:0 context:NULL];
		
		m_gaggedContacts = [[NSMutableSet alloc] init];
		
		// Input line history
		m_inputLineHistory = [[NSMutableArray alloc] init];
		
		// Observe group chat participants on attributes that should trigger a re-sorting of the participants list
		[self p_startObservingGroupChatParticipants];
	}
	return self;
}

- (void)dealloc
{
	[self p_stopObservingGroupChatParticipants];
	
	NSUserDefaultsController *prefsCtrl = [NSUserDefaultsController sharedUserDefaultsController];
	
	[prefsCtrl removeObserver:self forKeyPath:@"values.DisplayEmoticonImages"];
	[m_groupChat removeObserver:self forKeyPath:@"myGroupChatContact.affiliation"];
	[m_groupChat removeObserver:self forKeyPath:@"myGroupChatContact"];
	[m_groupChat removeObserver:self forKeyPath:@"nickname"];
	[m_groupChat removeObserver:self forKeyPath:@"active"];
	
	[m_groupChat release];
	[m_gaggedContacts release];
	[m_inputLineHistory release];
	[m_configController release];
	
	[m_overlayWindow close];
	[m_overlayWindow release];
	
	[super dealloc];
}

- (void)windowDidLoad
{
	[self p_setupToolbar];
	
	[m_chatViewsController setOwnerName:[[m_groupChat myGroupChatContact] userPresentableNickname]];
	
	// Workaround for centering the icons.
	[m_segmentedButton setLabel:nil forSegment:0];
	[[m_segmentedButton cell] setToolTip:NSLocalizedString(@"Choose Emoticon", @"") forSegment:0];
	// IB displays a round segmented button that apparently needs less space than the on that ends up
	// showing in the app (the flat segmented button used in metal windows).
	[m_segmentedButton sizeToFit];
	
	[m_topControlsBar setBackgroundColor:[NSColor colorWithPatternImage:[NSImage imageNamed:@"chatIDBackground"]]];
	[m_topControlsBar setBorderColor:[NSColor colorWithCalibratedWhite:0.60 alpha:1.0]];
	
	[self p_setSendFieldHidden:(![[self groupChat] isActive]) animate:NO];
	
	
	[m_participantsTableView setIntercellSpacing:NSMakeSize(3.0, 4.0)];
	[m_participantsTableView sizeToFit];
	
	NSSortDescriptor *sortByGagged = [[NSSortDescriptor alloc] initWithKey:@"gagged"
																 ascending:YES
																  selector:@selector(compare:)];
	NSSortDescriptor *sortByRole = [[NSSortDescriptor alloc] initWithKey:@"role"
															   ascending:NO
																selector:@selector(roleCompare:)];
	NSSortDescriptor *sortByNick = [[NSSortDescriptor alloc] initWithKey:@"nickname"
															   ascending:YES
																selector:@selector(caseInsensitiveCompare:)];
	[m_participantsController setSortDescriptors:[NSArray arrayWithObjects:sortByGagged, sortByRole, sortByNick, nil]];
	[sortByGagged release];
	[sortByRole release];
	[sortByNick release];
	
	// Make the participants list accept drops of contacts or contact entries
	[m_participantsTableView registerForDraggedTypes:
		[NSArray arrayWithObjects:LPRosterContactPboardType, LPRosterContactEntryPboardType, nil]];
	
	[m_participantsTableView setToolTip:NSLocalizedString(@"Drag a contact into this list to invite it to join this chat-room.", @"Group Chat participants list")];
}


- (void)p_startObservingGroupChatParticipants
{
	[[self groupChat] addObserver:self
					   forKeyPath:@"participants"
						  options:( NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld )
						  context:LPGroupChatParticipantsContext];
	
	NSEnumerator *participantEnum = [[[self groupChat] participants] objectEnumerator];
	LPGroupChatContact *participant;
	while (participant = [participantEnum nextObject])
		[self p_startObservingGroupChatParticipant:participant];
}

- (void)p_stopObservingGroupChatParticipants
{
	NSEnumerator *participantEnum = [[[self groupChat] participants] objectEnumerator];
	LPGroupChatContact *participant;
	while (participant = [participantEnum nextObject])
		[self p_stopObservingGroupChatParticipant:participant];
	
	[[self groupChat] removeObserver:self forKeyPath:@"participants"];
}

- (void)p_startObservingGroupChatParticipant:(LPGroupChatContact *)participant
{
	[participant addObserver:self forKeyPath:@"gagged" options:0 context:LPParticipantsAttribsContext];
	[participant addObserver:self forKeyPath:@"role" options:0 context:LPParticipantsAttribsContext];
	[participant addObserver:self forKeyPath:@"affiliation" options:0 context:LPParticipantsAttribsContext];
	[participant addObserver:self forKeyPath:@"nickname" options:0 context:LPParticipantsAttribsContext];
}

- (void)p_stopObservingGroupChatParticipant:(LPGroupChatContact *)participant
{
	[participant removeObserver:self forKeyPath:@"gagged"];
	[participant removeObserver:self forKeyPath:@"role"];
	[participant removeObserver:self forKeyPath:@"affiliation"];
	[participant removeObserver:self forKeyPath:@"nickname"];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == LPGroupChatContext) {
		if ([keyPath isEqualToString:@"active"]) {
			
			if ([[self groupChat] isActive])
				[self p_dismissOverlayWindow];
			
			[m_topControlsBar setBackgroundColor:
			 [NSColor colorWithPatternImage:([[self groupChat] isActive] ?
											 [NSImage imageNamed:@"chatIDBackground"] :
											 [NSImage imageNamed:@"chatIDBackground_Offline"] )]];
			
			[self p_setSendFieldHidden:(![[self groupChat] isActive]) animate:YES];
			
			// Update menus and the toolbar as action validation results may have changed
			[NSApp setWindowsNeedUpdate:YES];
		}
		else if ([keyPath isEqualToString:@"myGroupChatContact.affiliation"]) {
			// Update menus and the toolbar as action validation results may have changed
			[NSApp setWindowsNeedUpdate:YES];
		}
		else if ([keyPath isEqualToString:@"myGroupChatContact"] || [keyPath isEqualToString:@"nickname"]) {
			// Our nickname in the group chat has just changed
			LPGroupChatContact *myGroupChatContact = [m_groupChat myGroupChatContact];
			if (myGroupChatContact != nil) {
				[m_chatViewsController setOwnerName:[myGroupChatContact userPresentableNickname]];
			}
		}
	}
	else if (context == LPGroupChatParticipantsContext) {
		NSKeyValueChange keyValueChange = [[change valueForKey:NSKeyValueChangeKindKey] intValue];
		
		if (keyValueChange == NSKeyValueChangeInsertion) {
			NSEnumerator *participantEnum = [[change valueForKey:NSKeyValueChangeNewKey] objectEnumerator];
			LPGroupChatContact *participant;
			while (participant = [participantEnum nextObject])
				[self p_startObservingGroupChatParticipant:participant];			
		}
		else if (keyValueChange == NSKeyValueChangeRemoval) {
			NSEnumerator *participantEnum = [[change valueForKey:NSKeyValueChangeOldKey] objectEnumerator];
			LPGroupChatContact *participant;
			while (participant = [participantEnum nextObject])
				[self p_stopObservingGroupChatParticipant:participant];			
		}
	}
	else if (context == LPParticipantsAttribsContext) {
		// Make sure the participants icons are updated (they're displayed with the traditional NSTableDataSource methods)
		[m_participantsTableView setNeedsDisplay:YES];
		
		[m_participantsController rearrangeObjects];
	}
	else if ([keyPath isEqualToString:@"values.DisplayEmoticonImages"]) {
		BOOL displayImages = [[object valueForKeyPath:keyPath] boolValue];
		[m_chatViewsController showEmoticonsAsImages:displayImages];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (LPGroupChat *)groupChat
{
	return [[m_groupChat retain] autorelease];
}

- (NSString *)roomJID
{
	return [m_groupChat roomJID];
}

- (void)p_appendSystemMessage:(NSString *)msg
{
	[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:[msg stringByEscapingHTMLEntities]
													   divClass:@"systemMessage"
											scrollToVisibleMode:LPScrollWithAnimationIfAtBottom];
}


- (void)p_setupChatDocumentTitle
{
	NSString *timeFormat = NSLocalizedString(@"%Y-%m-%d %Hh%Mm%Ss",
											 @"time format for chat transcripts titles and filenames");
	NSMutableString *mutableTimeFormat = [timeFormat mutableCopy];
	
	// Make the timeFormat safe for filenames
	[mutableTimeFormat replaceOccurrencesOfString:@":" withString:@"." options:0
											range:NSMakeRange(0, [mutableTimeFormat length])];
	[mutableTimeFormat replaceOccurrencesOfString:@"/" withString:@"-" options:0
											range:NSMakeRange(0, [mutableTimeFormat length])];
	
	NSString *newTitle = [NSString stringWithFormat:
		NSLocalizedString(@"Group-chat on room \"%@\" on %@", @"filename and title for saved chat transcripts"),
		[[self groupChat] roomName],
		[[NSDate date] descriptionWithCalendarFormat:mutableTimeFormat timeZone:nil locale:nil]];
	
	[m_chatViewsController setChatDocumentTitle:newTitle];
	[mutableTimeFormat release];
}


- (void)p_setSendFieldHidden:(BOOL)hideFlag animate:(BOOL)animateFlag
{
	BOOL isInputHidden = (m_collapsedHeightWhenLastWentOffline >= 1.0);
	
	if (hideFlag != isInputHidden) {
		// The visibility of the text field doesn't match the state of the connection. We'll have to either show it or hide it.
		
		unsigned int chatViewAutoresizingMask = [m_chatTranscriptSplitView autoresizingMask];
		unsigned int inputBoxAutoresizingMask = [m_inputControlsBar autoresizingMask];
		
		// Disable the autoresizing of the views and make them stay where they are when we resize the window vertically
		[m_chatTranscriptSplitView setAutoresizingMask:NSViewMinYMargin];
		[m_inputControlsBar setAutoresizingMask:NSViewMinYMargin];
		
		float	deltaY = 0.0;
		BOOL	mustBecomeVisible = (!hideFlag && isInputHidden);
		
		if (mustBecomeVisible) {
			deltaY = m_collapsedHeightWhenLastWentOffline;
			m_collapsedHeightWhenLastWentOffline = 0.0;
		} else {
			m_collapsedHeightWhenLastWentOffline = NSHeight([m_inputControlsBar frame]);
			deltaY = -m_collapsedHeightWhenLastWentOffline;
		}
		
		if (mustBecomeVisible == NO)
			[[self window] makeFirstResponder:nil];
		
		[m_inputTextField setEnabled:mustBecomeVisible];
		[m_segmentedButton setEnabled:mustBecomeVisible];
		
		if (mustBecomeVisible)
			[[self window] makeFirstResponder:m_inputTextField];
		
		NSWindow *win = [m_inputControlsBar window];
		NSRect windowFrame = [win frame];
		
		windowFrame.origin.y -= deltaY;
		windowFrame.size.height += deltaY;
		
		[win setFrame:windowFrame display:YES animate:animateFlag];
		
		// Restore the autoresizing masks
		[m_chatTranscriptSplitView setAutoresizingMask:chatViewAutoresizingMask];
		[m_inputControlsBar setAutoresizingMask:inputBoxAutoresizingMask];
		
		// Readjust the size of the text field in case the window was resized while the input bar was collapsed
		if (mustBecomeVisible)
			[m_inputTextField calcContentSize];
		
		[self p_fixResizeIndicator];
	}
}


- (void)p_fixResizeIndicator
{
	// The resize indicator drawn on the corner of the window has some drawing issues when we resize the window
	// and it gets moved to or from over a scroll bar. The only way I got it to get drawn correctly was by disabling
	// the indicator immediatelly and reanabling it only on the next pass through the run loop.
	
	NSWindow *win = [self window];
	
	// Resize Indicator
	[win setShowsResizeIndicator:NO];
	
	
	NSMethodSignature *methodSig = [win methodSignatureForSelector:@selector(setShowsResizeIndicator:)];
	NSInvocation *inv = [NSInvocation invocationWithMethodSignature:methodSig];
	BOOL flag = YES;
	
	[inv setTarget:win];
	[inv setSelector:@selector(setShowsResizeIndicator:)];
	[inv setArgument:&flag atIndex:2];
	[inv retainArguments];
	[inv performSelector:@selector(invoke) withObject:nil afterDelay:0.0];
}


#pragma mark -
#pragma mark Rejoin Overlay Window


- (void)p_showRejoinOverlayWindowWithTitle:(NSString *)title message:(NSString *)message
{
	NSWindow	*myWin = [self window];
	NSView		*myWinContentView = [myWin contentView];
	NSRect		overlayWinFrame = [myWinContentView convertRectToBase:[myWinContentView bounds]];
	
	overlayWinFrame.origin = [myWin convertBaseToScreen:overlayWinFrame.origin];
	
	if (m_overlayWindow == nil) {
		m_overlayWindow = [[NSWindow alloc] initWithContentRect:overlayWinFrame
													  styleMask:NSBorderlessWindowMask
														backing:NSBackingStoreBuffered
														  defer:YES];
		
		[m_overlayWindow setOpaque:NO];
		[m_overlayWindow setHasShadow:NO];
		[m_overlayWindow setOneShot:YES];
		[m_overlayWindow setBackgroundColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.6667]];
		[m_overlayWindow setContentView:m_overlayView];
		[m_overlayWindow setReleasedWhenClosed:NO];
	}
	else {
		[m_overlayWindow setFrame:overlayWinFrame display:NO];
	}
	
	[m_overlayTitleLabel setStringValue:title];
	[m_overlayMessageLabel setStringValue:message];
	
	if ([m_overlayWindow parentWindow] == nil) {
		[myWin addChildWindow:m_overlayWindow ordered:NSWindowAbove];
	}
}


- (void)p_dismissOverlayWindow
{
	if (m_overlayWindow != nil && [m_overlayWindow parentWindow] == [self window]) {
		[[self window] removeChildWindow:m_overlayWindow];
		[m_overlayWindow orderOut:nil];
	}
}


#pragma mark -
#pragma mark Actions


- (IBAction)segmentClicked:(id)sender
{
	int clickedSegment = [sender selectedSegment];
    int clickedSegmentTag = [[sender cell] tagForSegment:clickedSegment];
	
	if (clickedSegmentTag == 0) {    // emoticons
		NSWindow *win = [self window];
		NSRect  buttonFrame = [sender frame];
		NSPoint topRight = [win convertBaseToScreen:[[sender superview] convertPoint:buttonFrame.origin
																			  toView:nil]];
		
		[sender setImage:[NSImage imageNamed:@"emoticonIconPressed"] forSegment:clickedSegment];
		[(NSView *)sender display];
		[m_chatViewsController pickEmoticonWithMenuTopRightAt:NSMakePoint(topRight.x + [sender widthForSegment:clickedSegment], topRight.y)
												 parentWindow:[self window]];
		[sender setImage:[NSImage imageNamed:@"emoticonIconUnpressed"] forSegment:clickedSegment];
		[(NSView *)sender display];
	}
}


- (IBAction)sendMessage:(id)sender
{
	NSAttributedString *attributedMessage = [m_inputTextField attributedStringValue];
	NSString *message = [attributedMessage stringByFlatteningAttachedEmoticons];
	
	// Check if the text is all made of whitespace.
	static NSCharacterSet *requiredCharacters = nil;
	if (requiredCharacters == nil) {
		requiredCharacters = [[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet] retain];
	}
	
	if ([message rangeOfCharacterFromSet:requiredCharacters].location != NSNotFound) {
		[m_groupChat sendPlainTextMessage:message];
	}
	
	// Store it in the input line history
	if ([m_inputLineHistory count] > 0)
		[m_inputLineHistory replaceObjectAtIndex:0 withObject:attributedMessage];
	else
		[m_inputLineHistory addObject:attributedMessage];
	
	if ([m_inputLineHistory count] > INPUT_LINE_HISTORY_ITEMS_MAX)
		[m_inputLineHistory removeObjectsInRange:NSMakeRange(INPUT_LINE_HISTORY_ITEMS_MAX, [m_inputLineHistory count] - INPUT_LINE_HISTORY_ITEMS_MAX)];
	[m_inputLineHistory insertObject:@"" atIndex:0];
	m_currentInputLineHistoryEntryIndex = 0;
	
	// Prepare the window to take another message from the user
	[[self window] makeFirstResponder:m_inputTextField];
	[m_inputTextField setStringValue:@""];
	[m_inputTextField performSelector:@selector(calcContentSize) withObject:nil afterDelay:0.0];
}


- (IBAction)changeTopic:(id)sender
{
	NSString *currentTopic = [[self groupChat] topic];
	[m_changeTopicTextField setStringValue:(currentTopic ? currentTopic : @"")];
	
	[NSApp beginSheet:m_changeTopicWindow
	   modalForWindow:[self window]
		modalDelegate:self didEndSelector:NULL contextInfo:NULL];
}


- (IBAction)changeTopicOKClicked:(id)sender
{
	[NSApp endSheet:m_changeTopicWindow];
	[m_changeTopicWindow orderOut:nil];
	
	[[self groupChat] setTopic:[m_changeTopicTextField stringValue]];
}


- (IBAction)changeNickname:(id)sender
{
	NSString *currentNick = [[self groupChat] nickname];
	[m_changeNicknameTextField setStringValue:(currentNick ? currentNick : @"")];
	[m_changeNicknameTextField selectText:nil];
	
	[NSApp beginSheet:m_changeNicknameWindow
	   modalForWindow:[self window]
		modalDelegate:self didEndSelector:NULL contextInfo:NULL];
}


- (IBAction)changeNicknameOKClicked:(id)sender
{
	[NSApp endSheet:m_changeNicknameWindow];
	[m_changeNicknameWindow orderOut:nil];
	
	[[self groupChat] setNickname:[m_changeNicknameTextField stringValue]];
}


- (IBAction)inviteContact:(id)sender
{
	[m_inviteContactTextField setStringValue:@""];
	[m_inviteContactTextField selectText:nil];
	[m_inviteContactReasonTextField setStringValue:@""];
	
	[NSApp beginSheet:m_inviteContactWindow
	   modalForWindow:[self window]
		modalDelegate:self didEndSelector:NULL contextInfo:NULL];
}


- (IBAction)inviteContactOKClicked:(id)sender
{
	[NSApp endSheet:m_inviteContactWindow];
	[m_inviteContactWindow orderOut:nil];
	
	[[self groupChat] inviteJID:[m_inviteContactTextField stringValue]
					 withReason:[m_inviteContactReasonTextField stringValue]];
}


- (IBAction)startPrivateChat:(id)sender
{
	NSEnumerator *participantsEnum = [[m_participantsController selectedObjects] objectEnumerator];
	LPGroupChatContact *participant;
	
	while (participant = [participantsEnum nextObject]) {
		NSString		*participantJID = [participant JIDInGroupChat];
		
		LPAccount		*account = [[self groupChat] account];
		LPRoster		*roster = [account roster];
		LPContactEntry	*entry = [roster contactEntryForAddress:participantJID
														account:account
							  createNewHiddenWithNameIfNotFound:[participant nickname]];
		
		// Start a chat with this contact entry
		if ([m_delegate respondsToSelector:@selector(groupChatController:openChatWithContactEntry:)]) {
			[m_delegate groupChatController:self openChatWithContactEntry:entry];
		}
	}
}


- (LPGroupChatConfigController *)p_groupChatConfigController
{
	if (m_configController == nil) {
		m_configController = [[LPGroupChatConfigController alloc] initWithGroupChatController:self];
	}
	return m_configController;
}


- (IBAction)configureChatRoom:(id)sender
{
	NSString *myAffiliation = [[[self groupChat] myGroupChatContact] affiliation];
	
	if (![myAffiliation isEqualToString:@"owner"]) {
		NSBeginAlertSheet(NSLocalizedString(@"You are not allowed to change the configuration for this room.", @""),
						  NSLocalizedString(@"OK", @""), nil, nil,
						  [self window], self, NULL, NULL, NULL,
						  NSLocalizedString(@"The configuration can only be changed by the owner of the room.", @""));
	}
	else {
		[[self p_groupChatConfigController] reloadConfigurationForm];
		
		[NSApp beginSheet:[[self p_groupChatConfigController] window]
		   modalForWindow:[self window]
			modalDelegate:self didEndSelector:NULL contextInfo:NULL];
	}
}


- (IBAction)actionSheetCancelClicked:(id)sender
{
	NSWindow *sheet = [[self window] attachedSheet];
	
	[NSApp endSheet:sheet];
	[sheet orderOut:nil];
}


- (IBAction)rejoinChatRoom:(id)sender
{
	LPGroupChat *gc = [self groupChat];
	
	if (![gc isActive])
		[gc retryJoinWithNickname:[gc lastSetNickname] password:[gc lastUsedPassword]];
}


- (IBAction)gagContact:(id)sender
{
	NSArray *contacts = [m_participantsController selectedObjects];
	
	[m_gaggedContacts addObjectsFromArray:contacts];
	
	NSEnumerator		*contactEnum = [contacts objectEnumerator];
	LPGroupChatContact	*contact;
	while (contact = [contactEnum nextObject]) {
		[contact setGagged:YES];
	}
}


- (IBAction)ungagContact:(id)sender
{
	NSArray *contacts = [m_participantsController selectedObjects];
	
	[m_gaggedContacts minusSet:[NSSet setWithArray:contacts]];
	
	NSEnumerator		*contactEnum = [contacts objectEnumerator];
	LPGroupChatContact	*contact;
	while (contact = [contactEnum nextObject]) {
		[contact setGagged:NO];
	}
}


- (IBAction)toggleGagContact:(id)sender
{
	NSSet *targets = [NSSet setWithArray:[m_participantsController selectedObjects]];
	if ([targets isSubsetOfSet:m_gaggedContacts])
		[self ungagContact:sender];
	else
		[self gagContact:sender];
}


- (IBAction)saveDocumentTo:(id)sender
{
	NSSavePanel *sp = [NSSavePanel savePanel];
	
	[sp setCanSelectHiddenExtension:YES];
	[sp setRequiredFileType:@"webarchive"];
	
	[sp beginSheetForDirectory:nil
						  file:[m_chatViewsController chatDocumentTitle]
				modalForWindow:[self window]
				 modalDelegate:self
				didEndSelector:@selector(p_savePanelDidEnd:returnCode:contextInfo:)
				   contextInfo:NULL];
}


- (void)p_savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		NSError *error;
		if (![m_chatViewsController saveDocumentToFile:[sheet filename] hideExtension:[sheet isExtensionHidden] error:&error]) {
			[self presentError:error];
		}
	}
}


- (IBAction)printDocument:(id)sender
{
	NSPrintOperation *op = [NSPrintOperation printOperationWithView:[[[m_chatWebView mainFrame] frameView] documentView]];
	[op runOperationModalForWindow:[self window]
						  delegate:nil
					didRunSelector:NULL
					   contextInfo:NULL];
}


#pragma mark Searching

- (IBAction)showFindPanel:(id)sender
{
	[[LPChatFindPanelController sharedFindPanel] showWindow:sender];
}

- (IBAction)findNext:(id)sender
{
	LPChatFindPanelController *findPanel = [LPChatFindPanelController sharedFindPanel];
	NSString *searchStr = [findPanel searchString];
	BOOL found = NO;
	
	if ([searchStr length] > 0)
		found = [m_chatWebView searchFor:searchStr direction:YES caseSensitive:NO wrap:YES];
	
	[findPanel searchStringWasFound:found];
}

- (IBAction)findPrevious:(id)sender
{
	LPChatFindPanelController *findPanel = [LPChatFindPanelController sharedFindPanel];
	NSString *searchStr = [findPanel searchString];
	BOOL found = NO;
	
	if ([searchStr length] > 0)
		found = [m_chatWebView searchFor:searchStr direction:NO caseSensitive:NO wrap:YES];
	
	[findPanel searchStringWasFound:found];
}

- (IBAction)useSelectionForFind:(id)sender
{
	NSString *selectedString = nil;
	id firstResponder = [[self window] firstResponder];
	
	if ([firstResponder isKindOfClass:[NSText class]])
		selectedString = [[firstResponder string] substringWithRange:[firstResponder selectedRange]];
	else if ([firstResponder isDescendantOf:m_chatWebView])
		selectedString = [[m_chatWebView selectedDOMRange] toString];
	
	if ([selectedString length] > 0)
		[[LPChatFindPanelController sharedFindPanel] setSearchString:selectedString];
}


#pragma mark Action Validation

- (BOOL)p_validateActionWithSelector:(SEL)action
{
	if (action == @selector(configureChatRoom:)) {
		return [[[[self groupChat] myGroupChatContact] affiliation] isEqualToString:@"owner"];
	}
	else if (action == @selector(startPrivateChat:)) {
		return ([[m_participantsController selectedObjects] count] > 0);
	}
	else if (action == @selector(gagContact:)) {
		NSSet *targets = [NSSet setWithArray:[m_participantsController selectedObjects]];
		return ([targets count] > 0 && ![targets isSubsetOfSet:m_gaggedContacts]);
	}
	else if (action == @selector(ungagContact:)) {
		NSSet *targets = [NSSet setWithArray:[m_participantsController selectedObjects]];
		return ([targets count] > 0 && [targets intersectsSet:m_gaggedContacts]);
	}
	else if (action == @selector(changeTopic:) ||
			 action == @selector(changeNickname:) ||
			 action == @selector(inviteContact:)) {
		return [[self groupChat] isActive];
	}
	else if (action == @selector(useSelectionForFind:)) {
		id firstResponder = [[self window] firstResponder];
		
		if ([firstResponder isKindOfClass:[NSText class]])
			return ([firstResponder selectedRange].length > 0);
		else if ([firstResponder isDescendantOf:m_chatWebView])
			return ([[[m_chatWebView selectedDOMRange] toString] length] > 0);
		else
			return NO;
	}
	else {
		return YES;
	}
}


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	
	if (action == @selector(toggleGagContact:)) {
		NSSet *targets = [NSSet setWithArray:[m_participantsController selectedObjects]];
		
		if ([targets isSubsetOfSet:m_gaggedContacts])
			[menuItem setState:NSOnState];
		else if (![targets intersectsSet:m_gaggedContacts])
			[menuItem setState:NSOffState];
		else
			[menuItem setState:NSMixedState];
	}
	
	return [self p_validateActionWithSelector:action];
}


#pragma mark -
#pragma mark LPGroupChat Delegate Methods


- (void)groupChat:(LPGroupChat *)chat didReceiveMessage:(NSString *)msg fromContact:(LPGroupChatContact *)contact
{
	if (![contact isGagged]) {
		NSString *messageHTML = [m_chatViewsController HTMLifyRawMessageString:msg];
		NSString *authorName = (contact ? [contact userPresentableNickname] : @"");
		NSString *htmlString = [m_chatViewsController HTMLStringForStandardBlockWithInnerHTML:messageHTML
																					timestamp:[NSDate date]
																				   authorName:authorName];
		
		// if it's an outbound message, also scroll down so that the user can see what he has just written
		[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:htmlString
														   divClass:@"messageBlock"
												scrollToVisibleMode:LPScrollWithAnimationIfAtBottom];
	}
}

- (void)groupChat:(LPGroupChat *)chat didReceiveSystemMessage:(NSString *)msg
{
	[self p_appendSystemMessage:msg];
}

- (void)groupChat:(LPGroupChat *)chat unableToProceedDueToWrongPasswordWithErrorMessage:(NSString *)msg
{
	[self p_appendSystemMessage:msg];
	
	[m_passwordPromptTextField selectText:nil];
	
	[NSApp beginSheet:m_passwordPromptWindow
	   modalForWindow:[self window]
		modalDelegate:self didEndSelector:NULL contextInfo:NULL];
}

- (IBAction)passwordPromptOKClicked:(id)sender
{
	[NSApp endSheet:m_passwordPromptWindow];
	[m_passwordPromptWindow orderOut:nil];
	
	[[self groupChat] retryJoinWithNickname:[[self groupChat] nickname]
								   password:[m_passwordPromptTextField stringValue]];
}

- (void)groupChat:(LPGroupChat *)chat unableToProceedDueToNicknameAlreadyInUseWithErrorMessage:(NSString *)msg
{
	[self p_appendSystemMessage:msg];
	
	NSString *currentNick = [[self groupChat] nickname];
	if (currentNick == nil) currentNick = @"";
	NSString *lastSetNick = [[self groupChat] lastSetNickname];
	if (lastSetNick == nil) lastSetNick = @"";
	
	NSString *labelFormatString = NSLocalizedString(@"The nickname \"%@\" is already in use on this server."
													@" Please choose an alternate nickname to proceed.",
													@"Chat room duplicate nickname error");
	
	[m_alternateNicknamePromptLabel setStringValue:[NSString stringWithFormat:labelFormatString, lastSetNick]];
	[m_alternateNicknamePromptTextField setStringValue:currentNick];
	[m_alternateNicknamePromptTextField selectText:nil];
	
	[NSApp beginSheet:m_alternateNicknamePromptWindow
	   modalForWindow:[self window]
		modalDelegate:self didEndSelector:NULL contextInfo:NULL];
}

- (IBAction)alternateNicknameOKClicked:(id)sender
{
	[NSApp endSheet:m_alternateNicknamePromptWindow];
	[m_alternateNicknamePromptWindow orderOut:nil];
	
	LPGroupChat *gc = [self groupChat];
	
	if ([gc isActive]) {
		[gc setNickname:[m_alternateNicknamePromptTextField stringValue]];
	}
	else {
		[gc retryJoinWithNickname:[m_alternateNicknamePromptTextField stringValue]
						 password:[[self groupChat] lastUsedPassword]];
	}
}

- (void)groupChat:(LPGroupChat *)chat didReceiveRoomConfigurationForm:(NSString *)configFormXML errorMessage:(NSString *)errorMsg
{
	[m_configController takeReceivedRoomConfigurationForm:configFormXML errorMessage:errorMsg];
}

- (void)groupChat:(LPGroupChat *)chat didReceiveResultOfRoomConfigurationModification:(BOOL)succeeded errorMessage:(NSString *)errorMsg
{
	[m_configController takeResultOfRoomConfigurationModification:succeeded errorMessage:errorMsg];
}

- (void)groupChat:(LPGroupChat *)chat didInviteJID:(NSString *)jid withReason:(NSString *)reason
{
	// Append a "system message" to the chat transcript
	NSString *msgFormat = NSLocalizedString(@"An invitation to join this chat has been sent to <%@>%@.",
											@"System message: invitation for group chat was sent");
	NSString *msg = [NSString stringWithFormat:msgFormat, jid,
		([reason length] > 0 ?
		 [NSString stringWithFormat:@" with reason \"%@\"", reason] :
		 @"")];
	
	[self p_appendSystemMessage:msg];
}

- (void)groupChat:(LPGroupChat *)chat didGetKickedBy:(LPGroupChatContact *)kickAuthor reason:(NSString *)reason
{
	// We already got the system message about the kick through the -groupChat:didReceiveSystemMessage: delegate method.
	// There's no need to write more stuff about it to the chat transcript in this delegate method.
	
	[self p_showRejoinOverlayWindowWithTitle:NSLocalizedString(@"You have just been kicked!", @"Group-chat overlay window")
									 message:[NSString stringWithFormat:
													NSLocalizedString(@"%@%@Click the \"Rejoin\" button to try to get back in.",
																	  @"Group-chat overlay window"),
													( kickAuthor != nil ?
													  [NSString stringWithFormat: NSLocalizedString(@"%@ has kicked you out of the chat-room. ",
																									@"Group-chat overlay window"),
															[kickAuthor userPresentableNickname]] :
													  @"" ),
													( [reason length] > 0 ?
													  [NSString stringWithFormat: NSLocalizedString(@"The reason was: \"%@\". ",
																									@"Group-chat overlay window"), reason] :
													  @"" )]];
}

- (void)groupChat:(LPGroupChat *)chat didGetBannedBy:(LPGroupChatContact *)banAuthor reason:(NSString *)reason
{
	// We already got the system message about the ban through the -groupChat:didReceiveSystemMessage: delegate method.
	// There's no need to write more stuff about it to the chat transcript in this delegate method.
	
	[self p_showRejoinOverlayWindowWithTitle:NSLocalizedString(@"You have just been banned!", @"Group-chat overlay window")
									 message:[NSString stringWithFormat:
													NSLocalizedString(@"%@%@Click the \"Rejoin\" button to try to get back in. (it will most"
																	  @" probably not work, but it doesn't hurt to try)",
																	  @"Group-chat overlay window"),
													( banAuthor != nil ?
													  [NSString stringWithFormat: NSLocalizedString(@"%@ has banned you from the chat-room. ",
																									@"Group-chat overlay window"),
															[banAuthor userPresentableNickname]] :
													  @"" ),
													( [reason length] > 0 ?
													  [NSString stringWithFormat: NSLocalizedString(@"The reason was: \"%@\". ",
																									@"Group-chat overlay window"), reason] :
													  @"" )]];
}


#pragma mark -
#pragma mark NSResponder Methods


- (void)keyDown:(NSEvent *)theEvent
{
	/* If a keyDown event reaches this low in the responder chain then it means that no text field is
	active to process the event. Activate the input text field and reroute the event that was received
	back to it. */
	if ([m_inputTextField canBecomeKeyView]) {
		NSWindow *window = [self window];
		[window makeFirstResponder:m_inputTextField];
		[[window firstResponder] keyDown:theEvent];
	} else {
		[super keyDown:theEvent];
	}
}


#pragma mark -
#pragma mark Private Methods


- (void)p_resizeInputFieldToContentsSize:(NSSize)newSize
{
	// Determine the new window frame
	float	heightDifference = newSize.height - NSHeight([m_inputTextField bounds]);
	
	if ((heightDifference > 0.5) || (heightDifference < -0.5)) {
		NSRect	newWindowFrame = [[self window] frame];
		
		newWindowFrame.size.height += heightDifference;
		newWindowFrame.origin.y -= heightDifference;
		
		// Make sure the window is completely enclosed within the screen rect
		NSRect screenRect = [[[self window] screen] visibleFrame];
		
		if (NSContainsRect(screenRect, newWindowFrame) == NO) {
			float dX = 0.0, dY = 0.0;
			
			if (NSMinX(screenRect) > NSMinX(newWindowFrame)) {
				dX = NSMinX(screenRect) - NSMinX(newWindowFrame);
			}
			else if (NSMaxX(screenRect) < NSMaxX(newWindowFrame)) {
				dX = NSMaxX(screenRect) - NSMaxX(newWindowFrame);
			}
			
			if (NSMinY(screenRect) > NSMinY(newWindowFrame)) {
				dY = NSMinY(screenRect) - NSMinY(newWindowFrame);
			}
			else if (NSMaxY(screenRect) < NSMaxY(newWindowFrame)) {
				dY = NSMaxY(screenRect) - NSMaxY(newWindowFrame);
			}
			
			newWindowFrame = NSOffsetRect(newWindowFrame, dX, dY);
		}
		
		// Do the actual resizing
		unsigned int splitViewResizeMask = [m_chatTranscriptSplitView autoresizingMask];
		unsigned int inputBoxResizeMask = [m_inputControlsBar autoresizingMask];
		
		[m_chatTranscriptSplitView setAutoresizingMask:NSViewMinYMargin];
		[m_inputControlsBar setAutoresizingMask:NSViewHeightSizable];
		
		[[self window] setFrame:newWindowFrame display:YES animate:YES];
		
		[m_inputControlsBar setAutoresizingMask:inputBoxResizeMask];
		[m_chatTranscriptSplitView setAutoresizingMask:splitViewResizeMask];
	}
}


#pragma mark -
#pragma mark NSWindow Delegate Methods


- (void)windowDidResize:(NSNotification *)notification
{
	NSWindow *win = [notification object];
	
	if (win == [self window]) {
		if (m_overlayWindow != nil && [m_overlayWindow parentWindow] == win) {
			NSView		*myWinContentView = [win contentView];
			NSRect		overlayWinFrame = [myWinContentView convertRectToBase:[myWinContentView bounds]];
			
			overlayWinFrame.origin = [win convertBaseToScreen:overlayWinFrame.origin];
			
			[m_overlayWindow setFrame:overlayWinFrame display:YES];
		}
	}
}


- (BOOL)windowShouldClose:(id)sender
{
	// Prevent accidental closing of the window
	NSBeginCriticalAlertSheet(NSLocalizedString(@"Are you sure you want to close this window?", @""),
							  NSLocalizedString(@"Close", @""), NSLocalizedString(@"Cancel", @""), nil,
							  [self window], self, @selector(p_windowCloseConfirmationSheetDidEnd:returnCode:contextInfo:), NULL, NULL,
							  NSLocalizedString(@"Closing the window will result in leaving the chat room \"%@\".", @""),
							  [[self groupChat] roomName]);
	return NO;
}

- (void)p_windowCloseConfirmationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertDefaultReturn) {
		[[self window] close];
	}
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	// If the WebView hasn't finished loading when the window is closed (extremely rare, but could happen), then we don't
	// want to do any of the setup that is about to happen in our frame load delegate methods, since the window is going away
	// anyway. If we allowed that setup to happen when the window is already closed it could originate some crashes, since
	// most of the stuff was already released by the time the delegate methods get called.
	[m_chatWebView setFrameLoadDelegate:nil];
	[m_chatWebView setUIDelegate:nil];
	
	[m_groupChat endGroupChat];
	[m_groupChat setDelegate:nil];
	
	if ([m_delegate respondsToSelector:@selector(groupChatControllerWindowWillClose:)]) {
		[m_delegate groupChatControllerWindowWillClose:self];
	}
}


#pragma mark -
#pragma mark WebView Frame Load Delegate Methods


- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	[self p_setupChatDocumentTitle];
	
	[m_chatViewsController dumpQueuedMessagesToWebView];
	[m_chatViewsController showEmoticonsAsImages:[[NSUserDefaults standardUserDefaults] boolForKey:@"DisplayEmoticonImages"]];
}


#pragma mark WebView UI Delegate Methods


- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	if (sender == m_chatWebView) {
		NSMutableArray	*itemsToReturn = [NSMutableArray array];
		NSEnumerator	*enumerator = [defaultMenuItems objectEnumerator];
		id				menuItem;
		
		while ((menuItem = [enumerator nextObject]) != nil) {
			switch ([menuItem tag]) {
				case WebMenuItemTagCopyLinkToClipboard:
				case WebMenuItemTagCopy:
				case WebMenuItemTagSpellingGuess:
				case WebMenuItemTagNoGuessesFound:
				case WebMenuItemTagIgnoreSpelling:
				case WebMenuItemTagLearnSpelling:
				case WebMenuItemTagOther:
					[itemsToReturn addObject:menuItem];
					break;
			}
		}
		
		return itemsToReturn;
	}
	else {
		return [NSArray array];
	}
}


- (unsigned)webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	// We don't want the WebView to process anything dropped on it
	return WebDragDestinationActionNone;
}


- (unsigned)webView:(WebView *)sender dragSourceActionMaskForPoint:(NSPoint)point
{
	return WebDragSourceActionAny;
}


#pragma mark -

#pragma mark NSControl Delegate Methods

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	m_currentInputLineHistoryEntryIndex = 0;
}


- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	if (command == @selector(pageDown:)						|| command == @selector(pageUp:)				||
		command == @selector(scrollPageDown:)				|| command == @selector(scrollPageUp:)			||
		/* The following two selectors are undocumented. They're used by Cocoa to represent a Home or End key press. */
		command == @selector(scrollToBeginningOfDocument:)	|| command == @selector(scrollToEndOfDocument:)	 )
	{
		[[[m_chatWebView mainFrame] frameView] doCommandBySelector:command];
		return YES;
	}
	else if (command == @selector(moveToBeginningOfDocument:) || command == @selector(moveToEndOfDocument:)) {
		
		if (m_currentInputLineHistoryEntryIndex == 0) {
			if ([m_inputLineHistory count] > 0) {
				[m_inputLineHistory replaceObjectAtIndex:0 withObject:[m_inputTextField attributedStringValue]];
			}
			else {
				[m_inputLineHistory addObject:[m_inputTextField attributedStringValue]];
			}
		}
		
		if (command == @selector(moveToBeginningOfDocument:))
			m_currentInputLineHistoryEntryIndex = (m_currentInputLineHistoryEntryIndex + 1) % [m_inputLineHistory count];
		else
			m_currentInputLineHistoryEntryIndex = (m_currentInputLineHistoryEntryIndex > 0 ?
												   m_currentInputLineHistoryEntryIndex :
												   [m_inputLineHistory count]) - 1;
		
		[m_inputTextField setAttributedStringValue:[m_inputLineHistory objectAtIndex:m_currentInputLineHistoryEntryIndex]];
		[m_inputTextField performSelector:@selector(calcContentSize) withObject:nil afterDelay:0.0];
		
		return YES;
	}
	else {
		return NO;
	}
}


#pragma mark LPGrowingTextField Delegate Methods

- (void)growingTextField:(LPGrowingTextField *)textField contentSizeDidChange:(NSSize)neededSize
{
	[self p_resizeInputFieldToContentsSize:neededSize];
}


#pragma mark -
#pragma mark NSTableView Delegate Methods


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [[m_participantsController arrangedObjects] count];
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if ([[aTableColumn identifier] isEqualToString:@"contactIcon"]) {
		LPGroupChatContact *contact = [[m_participantsController arrangedObjects] objectAtIndex:rowIndex];
		
		if ([contact isGagged]) {
			return [NSImage imageNamed:@"muc_gagged_participant"];
		}
		else if ([[contact affiliation] isEqualToString:@"owner"]) {
			return [NSImage imageNamed:@"muc_owner"];
		}
		else if ([[contact role] isEqualToString:@"moderator"]) {
			return [NSImage imageNamed:@"muc_moderator"];
		}
		else {
			return [NSImage imageNamed:@"muc_participant"];
		}
	}
	else {
		return nil;
	}
}


- (BOOL)tableView:(NSTableView *)tableView shouldShowCellExpansionForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	return NO;
}


- (NSString *)tableView:(NSTableView *)aTableView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(int)row mouseLocation:(NSPoint)mouseLocation
{
	LPGroupChatContact *contact = [[m_participantsController arrangedObjects] objectAtIndex:row];
	NSString *realJID = [contact realJID];
	NSString *statusMessage = [contact statusMessage];
	
	return [NSString stringWithFormat:@"%@\n%@%@, %@\n\n%@%@%@",
		[contact nickname],
		([contact isGagged] ? [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"(gagged)", @"")] : @""),
		[contact role], [contact affiliation],
		([realJID length] > 0 ? [NSString stringWithFormat:@"%@\n\n", realJID] : @""),
		NSLocalizedStringFromTable(LPStatusStringFromStatus([contact status]), @"Status", @""),
		([statusMessage length] > 0 ? [NSString stringWithFormat:@" : \"%@\"", statusMessage] : @"")];
}


- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if ([[aTableColumn identifier] isEqualToString:@"contactName"]) {
		LPGroupChatContact *contact = [[m_participantsController arrangedObjects] objectAtIndex:rowIndex];
		NSString *role = [contact role];
		
		NSColor *textColor = nil;
		
		if ([[aTableView selectedRowIndexes] containsIndex:rowIndex]) {
			textColor = [NSColor whiteColor];
		}
		else {
			if ([role isEqualToString:@"moderator"]) {
				textColor = [NSColor redColor];
			}
			else if ([role isEqualToString:@"visitor"]) {
				textColor = [NSColor grayColor];
			}
			else {  // @"participant"
				textColor = [NSColor blackColor];
			}
			
			if ([contact isGagged]) {
				textColor = [textColor blendedColorWithFraction:0.5 ofColor:[NSColor whiteColor]];
			}
		}
		
		[aCell setTextColor:textColor];
	}
}


//- (BOOL)tableView:(NSTableView *)aTableView writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
//{
//	// This method is deprecated in 10.4, but the alternative doesn't exist on 10.3, so we have to use this one.
//	
//}


- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	NSDragOperation		resultOp = NSDragOperationNone;
	NSArray				*draggedTypes = [[info draggingPasteboard] types];
	NSArray				*itemsBeingDragged = nil;
	
	if ([draggedTypes containsObject:LPRosterContactEntryPboardType]) {
		itemsBeingDragged = LPRosterContactEntriesBeingDragged([info draggingPasteboard]);
	}
	else if ([draggedTypes containsObject:LPRosterContactPboardType]) {
		itemsBeingDragged = LPRosterContactsBeingDragged([info draggingPasteboard]);
	}
	
	if ([itemsBeingDragged someOnlineItemInArrayPassesCapabilitiesPredicate:@selector(canDoMUC)]) {
		resultOp = NSDragOperationGeneric;
		// Highlight the whole table
		[aTableView setDropRow:-1 dropOperation:NSTableViewDropOn];
	}
	
	return resultOp;
}


- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	NSPasteboard		*pboard = [info draggingPasteboard];
	NSArray				*draggedTypes = [pboard types];
	NSDragOperation		dragOpMask = [info draggingSourceOperationMask];
	
	if (dragOpMask & NSDragOperationGeneric) {
		if ([draggedTypes containsObject:LPRosterContactEntryPboardType]) {
			NSArray			*entriesBeingDragged = LPRosterContactEntriesBeingDragged([info draggingPasteboard]);
			
			NSEnumerator	*entriesEnum = [entriesBeingDragged objectEnumerator];
			LPContactEntry	*entry;
			
			while (entry = [entriesEnum nextObject])
				if ([entry canDoMUC])
					[[self groupChat] inviteJID:[entry address] withReason:@""];
		}
		else if ([draggedTypes containsObject:LPRosterContactPboardType]) {
			NSArray			*contactsBeingDragged = LPRosterContactsBeingDragged([info draggingPasteboard]);
			NSEnumerator	*contactsEnum = [contactsBeingDragged objectEnumerator];
			LPContact		*contact;
			
			while (contact = [contactsEnum nextObject]) {
				LPContactEntry *entry = [[contact contactEntries] firstOnlineItemInArrayPassingCapabilitiesPredicate:@selector(canDoMUC)];
				if (entry)
					[[self groupChat] inviteJID:[entry address] withReason:@""];
			}
		}
	}
		
	return YES;
}


#pragma mark -
#pragma mark NSSplitView Delegate Methods


- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	NSAssert(([[sender subviews] count] == 2), @"We were expecting exactly 2 views inside the NSSplitView!");
	
	NSView *leftPane = [[sender subviews] objectAtIndex:0];
	NSView *rightPane = [[sender subviews] objectAtIndex:1];
	NSRect newLeftPaneFrame = [leftPane frame];
	NSRect newRightPaneFrame = [rightPane frame];
	NSRect newSplitViewFrame = [sender frame];
	
	float widthDelta = NSWidth(newSplitViewFrame) - oldSize.width;
	
	newLeftPaneFrame.size.height = newRightPaneFrame.size.height = newSplitViewFrame.size.height;
	newRightPaneFrame.origin.x += widthDelta;
	newLeftPaneFrame.size.width += widthDelta;
	
	[leftPane setFrame:newLeftPaneFrame];
	[rightPane setFrame:newRightPaneFrame];
}


#pragma mark -
#pragma mark NSToolbar Methods


- (void)p_setupToolbar 
{
	// Create a new toolbar instance
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"LPGroupChatToolbar"];
	
	//[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
	[toolbar setSizeMode:NSToolbarSizeModeSmall];
	
	// Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults 
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	
	// We are the delegate.
	[toolbar setDelegate:self];
	
	// Attach the toolbar to the window.
	[[self window] setToolbar:toolbar];
	[toolbar release];
}


- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInserted 
{
	// Create our toolbar items.
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
	
	if ([identifier isEqualToString:ToolbarSetTopicIdentifier])
	{
		[item setLabel:NSLocalizedString(@"Set Topic", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Set Topic", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"iconMUCtopic"]];
		[item setToolTip:NSLocalizedString(@"Change the topic of this chat-room.", @"toolbar button")];
		[item setAction:@selector(changeTopic:)];
		[item setTarget:self];
	}
	else if ([identifier isEqualToString:ToolbarSetNicknameIdentifier])
	{
		[item setLabel:NSLocalizedString(@"Set Nickname", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Set Nickname", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
		[item setToolTip:NSLocalizedString(@"Change your nickname on this chat-room.", @"toolbar button")];
		[item setAction:@selector(changeNickname:)];
		[item setTarget:self];
	}
	else if ([identifier isEqualToString:ToolbarInviteIdentifier])
	{
		[item setLabel:NSLocalizedString(@"Invite", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Invite Contact", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"iconMUCinvite"]];
		[item setToolTip:NSLocalizedString(@"Invite another contact to this chat-room.", @"toolbar button")];
		[item setAction:@selector(inviteContact:)];
		[item setTarget:self];
	}
	else if ([identifier isEqualToString:ToolbarPrivateChatIdentifier])
	{
		[item setLabel:NSLocalizedString(@"Private Chat", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Start Private Chat", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"iconMUCpvt"]];
		[item setToolTip:NSLocalizedString(@"Start a private chat with another participant of this chat-room.", @"toolbar button")];
		[item setAction:@selector(startPrivateChat:)];
		[item setTarget:self];
	}
	else if ([identifier isEqualToString:ToolbarConfigRoomIdentifier])
	{
		[item setLabel:NSLocalizedString(@"Configure Room", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Configure Room", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
		[item setToolTip:NSLocalizedString(@"Configure this chat-room.", @"toolbar button")];
		[item setAction:@selector(configureChatRoom:)];
		[item setTarget:self];
	}
	else
	{
		// Invalid identifier!
		NSLog(@"WARNING: Invalid toolbar item identifier: %@", identifier);
		item = nil;
	}
	
	return [item autorelease];
}


- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar 
{
    return [NSArray arrayWithObjects:
		ToolbarSetTopicIdentifier,
		ToolbarSetNicknameIdentifier,
		ToolbarInviteIdentifier,
		ToolbarPrivateChatIdentifier,
		NSToolbarSeparatorItemIdentifier,
		ToolbarConfigRoomIdentifier,
		NSToolbarSeparatorItemIdentifier,
		NSToolbarPrintItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarSeparatorItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		nil];
}


- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar 
{	
    return [NSArray arrayWithObjects:
		ToolbarSetTopicIdentifier,
		ToolbarSetNicknameIdentifier,
		ToolbarInviteIdentifier,
		ToolbarPrivateChatIdentifier,
		ToolbarConfigRoomIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarPrintItemIdentifier,
		nil];
}


- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
	SEL action = [theItem action];
	
	if (action == @selector(configureChatRoom:)) {
		BOOL isOwner = [[[[self groupChat] myGroupChatContact] affiliation] isEqualToString:@"owner"];
		[theItem setToolTip:( isOwner ?
							  NSLocalizedString(@"Configure this chat-room.", @"toolbar button") :
							  NSLocalizedString(@"You must be the room owner in order to be allowed to configure it.", @"toolbar button") )];
	}
	
	return [self p_validateActionWithSelector:action];
}


@end
