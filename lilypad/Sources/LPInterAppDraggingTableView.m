//
//  LPInterAppDraggingTableView.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPInterAppDraggingTableView.h"


@implementation LPInterAppDraggingTableView

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	if (isLocal)
		return NSDragOperationEvery;
	else
		return NSDragOperationCopy;
}

@end
