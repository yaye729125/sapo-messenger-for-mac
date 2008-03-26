//
//  LPCrashReporter.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface LPCrashReporter : NSObject
{
	id				m_delegate;
	NSMutableArray	*m_accumulatedExceptionLogsPList;
	NSArray			*m_newCrashLogsPathnamesSinceLastCheck;
}

- initWithDelegate:(id)delegate;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (id)accumulatedExceptionLogsPList;
- (void)postAccumulatedExceptionLogsPListToHTTPURL:(NSURL *)httpURL;

- (NSArray *)newCrashLogsPathnamesSinceLastCheck;
- (void)postNewCrashLogsToHTTPURL:(NSURL *)httpURL;

@end


@interface NSObject (LPCrashReporterDelegate)
/*
 * This method will be invoked only once in the main thread. It can be used to start some kind
 * of interaction with the user. If any additional unhandled exceptions are caught while this
 * method's invocation hasn't returned yet, then they're all accumulated internally and will
 * all be sent when -[LPCrashReporter postAccumulatedExceptionLogsPListToHTTPURL:] gets called.
 * You can block program execution while inside this delegate method (for running a modal loop,
 * for example) and any method from LPCrashReporter can be invoked safely.
 */
- (void)crashReporterDidCatchFirstUnhandledException:(LPCrashReporter *)crashReporter;
@end
