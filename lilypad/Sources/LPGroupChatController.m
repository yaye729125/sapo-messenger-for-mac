//
//  LPGroupChatController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
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


// KVO Contexts
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


@interface LPGroupChatController (Private)
- (void)p_startObservingGroupChatParticipants;
- (void)p_stopObservingGroupChatParticipants;
- (void)p_startObservingGroupChatParticipant:(LPGroupChatContact *)participant;
- (void)p_stopObservingGroupChatParticipant:(LPGroupChatContact *)participant;
- (void)p_setupChatDocumentTitle;
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
		
		[m_groupChat addObserver:self forKeyPath:@"active" options:0 context:NULL];
		[m_groupChat addObserver:self forKeyPath:@"myGroupChatContact.affiliation" options:0 context:NULL];
		[prefsCtrl addObserver:self forKeyPath:@"values.DisplayEmoticonImages" options:0 context:NULL];
		
		m_gaggedContacts = [[NSMutableSet alloc] init];
		
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
	[m_groupChat removeObserver:self forKeyPath:@"active"];
	
	[m_groupChat release];
	[m_gaggedContacts release];
	[m_configController release];
	[super dealloc];
}

- (void)windowDidLoad
{
	[self p_setupToolbar];
	
	[m_chatViewsController setOwnerName:[m_groupChat nickname]];
	
	// Workaround for centering the icons.
	[m_segmentedButton setLabel:nil forSegment:0];
	[[m_segmentedButton cell] setToolTip:NSLocalizedString(@"Choose Emoticon", @"") forSegment:0];
	// IB displays a round segmented button that apparently needs less space than the on that ends up
	// showing in the app (the flat segmented button used in metal windows).
	[m_segmentedButton sizeToFit];
	
	[m_topControlsBar setBackgroundColor:[NSColor colorWithPatternImage:[NSImage imageNamed:@"chatIDBackground"]]];
	[m_topControlsBar setBorderColor:[NSColor colorWithCalibratedWhite:0.60 alpha:1.0]];
	
	[m_inputControlsBar setShadedBackgroundWithOrientation:LPVerticalBackgroundShading
											  minEdgeColor:[NSColor colorWithCalibratedWhite:0.79 alpha:1.0]
											  maxEdgeColor:[NSColor colorWithCalibratedWhite:0.99 alpha:1.0]];
	[m_inputControlsBar setBorderColor:[NSColor colorWithCalibratedWhite:0.80 alpha:1.0]];
	
	
	[m_participantsTableView setIntercellSpacing:NSMakeSize(15.0, 6.0)];
	
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
	[participant addObserver:self forKeyPath:@"nickname" options:0 context:LPParticipantsAttribsContext];
}

- (void)p_stopObservingGroupChatParticipant:(LPGroupChatContact *)participant
{
	[participant removeObserver:self forKeyPath:@"gagged"];
	[participant removeObserver:self forKeyPath:@"role"];
	[participant removeObserver:self forKeyPath:@"nickname"];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"active"] || [keyPath isEqualToString:@"myGroupChatContact.affiliation"]) {
		// Update menus and the toolbar as action validation results may have changed
		[NSApp setWindowsNeedUpdate:YES];
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
											scrollToVisibleMode:LPScrollWithAnimationIfConvenient];
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
	NSString *message = [[m_inputTextField attributedStringValue] stringByFlatteningAttachedEmoticons];
	
	// Check if the text is all made of whitespace.
	static NSCharacterSet *requiredCharacters = nil;
	if (requiredCharacters == nil) {
		requiredCharacters = [[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet] retain];
	}
	
	if ([message rangeOfCharacterFromSet:requiredCharacters].location != NSNotFound) {
		[m_groupChat sendPlainTextMessage:message];
	}
	
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
		
		LPRoster		*roster = [[[self groupChat] account] roster];
		LPContactEntry	*entry = [roster contactEntryForAddress:participantJID
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


- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
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
		NSString *authorName = (contact ? [contact nickname] : @"");
		NSString *htmlString = [m_chatViewsController HTMLStringForStandardBlockWithInnerHTML:messageHTML
																					timestamp:[NSDate date]
																				   authorName:authorName];
		
		// if it's an outbound message, also scroll down so that the user can see what he has just written
		[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:htmlString
														   divClass:@"messageBlock"
												scrollToVisibleMode:LPScrollWithAnimationIfConvenient];
	}
}

- (void)groupChat:(LPGroupChat *)chat didReceiveSystemMessage:(NSString *)msg
{
	[self p_appendSystemMessage:msg];
}

- (void)groupChat:(LPGroupChat *)chat unableToJoinDueToWrongPasswordWithErrorMessage:(NSString *)msg
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
	
	[[self groupChat] retryJoinWithPassword:[m_passwordPromptTextField stringValue]];
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
	
	[m_groupChat endGroupChat];
	
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

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	if (command == @selector(pageDown:)						|| command == @selector(pageUp:)				||
		command == @selector(scrollPageDown:)				|| command == @selector(scrollPageUp:)			||
		command == @selector(moveToBeginningOfDocument:)	|| command == @selector(moveToEndOfDocument:)	||
		/* The following two selectors are undocumented. They're used by Cocoa to represent a Home or End key press. */
		command == @selector(scrollToBeginningOfDocument:)	|| command == @selector(scrollToEndOfDocument:)	 )
	{
		[[[m_chatWebView mainFrame] frameView] doCommandBySelector:command];
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
	return 0;
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	return nil;
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
		itemsBeingDragged = LPRosterContactEntriesBeingDragged(info);
	}
	else if ([draggedTypes containsObject:LPRosterContactPboardType]) {
		itemsBeingDragged = LPRosterContactsBeingDragged(info);
	}
	
	if ([itemsBeingDragged someItemInArrayPassesCapabilitiesPredicate:@selector(canDoMUC)]) {
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
			NSArray			*entriesBeingDragged = LPRosterContactEntriesBeingDragged(info);
			
			NSEnumerator	*entriesEnum = [entriesBeingDragged objectEnumerator];
			LPContactEntry	*entry;
			
			while (entry = [entriesEnum nextObject])
				if ([entry canDoMUC])
					[[self groupChat] inviteJID:[entry address] withReason:@""];
		}
		else if ([draggedTypes containsObject:LPRosterContactPboardType]) {
			NSArray			*contactsBeingDragged = LPRosterContactsBeingDragged(info);
			NSEnumerator	*contactsEnum = [contactsBeingDragged objectEnumerator];
			LPContact		*contact;
			
			while (contact = [contactsEnum nextObject]) {
				LPContactEntry *entry = [contact firstContactEntryWithCapsFeature:@"http://jabber.org/protocol/muc"];
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
		[item setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
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
		[item setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
		[item setToolTip:NSLocalizedString(@"Invite another contact to this chat-room.", @"toolbar button")];
		[item setAction:@selector(inviteContact:)];
		[item setTarget:self];
	}
	else if ([identifier isEqualToString:ToolbarPrivateChatIdentifier])
	{
		[item setLabel:NSLocalizedString(@"Private Chat", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Start Private Chat", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
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
