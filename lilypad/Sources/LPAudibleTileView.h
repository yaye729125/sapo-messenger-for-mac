//
//  LPAudibleTileView.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@interface LPAudibleTileView : WebView
{
	id					m_delegate;
	
	BOOL				m_hasAudibleContent;
	NSBitmapImageRep	*m_cachedImageRep;
	
	int					m_previousMouseEventNr;
}

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (BOOL)hasAudibleFileContent;
- (NSBitmapImageRep *)cachedBitmapImageRep;
- (void)setAudibleFileContentPath:(NSString *)filepath;

@end


@interface NSObject (LPAudibleTileViewDelegate)
/* This method will be invoked in the delegate for each mouse click that we get inside the tile. */
- (void)audibleTileViewGotMouseDown:(LPAudibleTileView *)view;
@end
