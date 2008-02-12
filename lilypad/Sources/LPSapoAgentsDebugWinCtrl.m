//
//  LPSapoAgentsDebugWinCtrl.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPSapoAgentsDebugWinCtrl.h"
#import "LPAccount.h"
#import "LPServerItemsInfo.h"


@implementation LPSapoAgentsDebugWinCtrl

- initWithAccount:(LPAccount *)account
{
	if (self = [self initWithWindowNibName:@"SapoAgentsDebugWindow"]) {
		m_account = [account retain];
		
		[account addObserver:self forKeyPath:@"serverItemsInfo.featuresByItem" options:0 context:NULL];
		[account addObserver:self forKeyPath:@"serverItemsInfo.itemsByFeature" options:0 context:NULL];
		[account addObserver:self forKeyPath:@"sapoAgents.dictionaryRepresentation" options:0 context:NULL];
	}
	return self;
}

- (void)dealloc
{
	[m_account removeObserver:self forKeyPath:@"sapoAgents.dictionaryRepresentation"];
	[m_account removeObserver:self forKeyPath:@"serverItemsInfo.itemsByFeature"];
	[m_account removeObserver:self forKeyPath:@"serverItemsInfo.featuresByItem"];
	[m_account release];
	
	[super dealloc];
}

- (void)windowDidLoad
{
	[[self window] setTitle:[NSString stringWithFormat:@"disco#info & sapo:agents for Account \"%@\" (%@)",
							 [m_account description], [m_account JID]]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"serverItemsInfo.featuresByItem"]) {
		[m_discoInfoBrowserByItem reloadColumn:0];
	}
	else if ([keyPath isEqualToString:@"serverItemsInfo.itemsByFeature"]) {
		[m_discoInfoBrowserByFeature reloadColumn:0];
	}
	else if ([keyPath isEqualToString:@"sapoAgents.dictionaryRepresentation"]) {
		[m_sapoAgentsBrowser reloadColumn:0];
	}
}

#pragma mark NSBrowser Delegate

- (int)browser:(NSBrowser *)sender numberOfRowsInColumn:(int)column
{
	int count = 0;
	if (sender == m_discoInfoBrowserByItem || sender == m_discoInfoBrowserByFeature) {
		NSDictionary *dataDict = ( (sender == m_discoInfoBrowserByItem) ?
								   [[m_account serverItemsInfo] featuresByItem] :
								   [[m_account serverItemsInfo] itemsByFeature] );
		
		if (column == 0) {
			count = [dataDict count];
		}
		else if (column == 1) {
			NSArray	*sortedKeys = [[dataDict allKeys] sortedArrayUsingSelector:@selector(compare:)];
			int		selectedKeyIdx = [sender selectedRowInColumn:(column - 1)];
			NSArray	*infoValues = [dataDict objectForKey:[sortedKeys objectAtIndex:selectedKeyIdx]];
			
			count = [infoValues count];
		}
	}
	else if (sender == m_sapoAgentsBrowser) {
		NSDictionary *sapoAgentsDict = [[m_account sapoAgents] dictionaryRepresentation];
		
		if (column == 0) {
			count = [sapoAgentsDict count];
		}
		else {
			NSArray			*sortedCol0Keys = [[sapoAgentsDict allKeys] sortedArrayUsingSelector:@selector(compare:)];
			int				selectedCol0KeyIdx = [m_sapoAgentsBrowser selectedRowInColumn:0];
			NSDictionary	*col1ValuesDict = [sapoAgentsDict objectForKey:[sortedCol0Keys objectAtIndex:selectedCol0KeyIdx]];
			
			if (column == 1) {
				count = [col1ValuesDict count];
			}
			else if (column == 2) {
				NSArray *sortedCol1Keys = [[col1ValuesDict allKeys] sortedArrayUsingSelector:@selector(compare:)];
				int		selectedCol1KeyIdx = [m_sapoAgentsBrowser selectedRowInColumn:1];
				id		col2Values = [col1ValuesDict objectForKey:[sortedCol1Keys objectAtIndex:selectedCol1KeyIdx]];
				
				if ([col2Values respondsToSelector:@selector(count)]) {
					count = [col2Values count];
				} else {
					return 1;
				}
			}
		}
	}
	return count;
}


- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column
{
	if (sender == m_discoInfoBrowserByItem || sender == m_discoInfoBrowserByFeature) {
		NSDictionary	*dataDict = ( (sender == m_discoInfoBrowserByItem) ?
									  [[m_account serverItemsInfo] featuresByItem] :
									  [[m_account serverItemsInfo] itemsByFeature] );
		NSArray			*sortedKeys = [[dataDict allKeys] sortedArrayUsingSelector:@selector(compare:)];

		if (column == 0) {
			[cell setStringValue:[sortedKeys objectAtIndex:row]];
			[cell setLeaf:NO];
		}
		else if (column == 1) {
			int		selectedKeyIdx = [sender selectedRowInColumn:(column - 1)];
			NSArray	*infoValues = [dataDict objectForKey:[sortedKeys objectAtIndex:selectedKeyIdx]];
			
			infoValues = [infoValues sortedArrayUsingSelector:@selector(compare:)];
			
			[cell setStringValue:[infoValues objectAtIndex:row]];
			[cell setLeaf:YES];
		}
	}
	else if (sender == m_sapoAgentsBrowser) {
		NSDictionary *sapoAgentsDict = [[m_account sapoAgents] dictionaryRepresentation];
		NSArray			*sortedCol0Keys = [[sapoAgentsDict allKeys] sortedArrayUsingSelector:@selector(compare:)];

		if (column == 0) {
			[cell setStringValue:[sortedCol0Keys objectAtIndex:row]];
			[cell setLeaf:NO];
		}
		else {
			int				selectedCol0KeyIdx = [m_sapoAgentsBrowser selectedRowInColumn:0];
			NSDictionary	*col1ValuesDict = [sapoAgentsDict objectForKey:[sortedCol0Keys objectAtIndex:selectedCol0KeyIdx]];
			NSArray			*sortedCol1Keys = [[col1ValuesDict allKeys] sortedArrayUsingSelector:@selector(compare:)];

			if (column == 1) {
				[cell setStringValue:[sortedCol1Keys objectAtIndex:row]];
				[cell setLeaf:NO];
			}
			else if (column == 2) {
				int		selectedCol1KeyIdx = [m_sapoAgentsBrowser selectedRowInColumn:1];
				id		col2Value = [col1ValuesDict objectForKey:[sortedCol1Keys objectAtIndex:selectedCol1KeyIdx]];
				
				if (row == 0) {
					[cell setStringValue:col2Value];
					[cell setLeaf:YES];
				} else {
					[NSException raise:@"LPSapoAgentsDebugWinCtrlException"
								format:@"Invalid sapo:agents browser row (row > 0) for last column (col = 2)."];
				}
			}
		}
	}
}


@end
