//
//  LPReleaseNotesController.h
//  Lilypad
//
//  Created by João Pavão on 08/06/30.
//  Copyright 2008 Sapo. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@interface LPReleaseNotesController : NSWindowController
{
	IBOutlet WebView *m_webView;
}
@end
