//
//  LPInterAppDraggingTableView.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
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
