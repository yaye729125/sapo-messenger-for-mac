//
//  LPEmoticonMatrix.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPEmoticonSet;


@interface LPEmoticonMatrix : NSMatrix
{
	NSCell	*m_highlightedCell;
}
- (void)loadEmoticonsFromSet:(LPEmoticonSet *)emoticonSet;
- (NSCell *)highlightedCell;
- (void)setHighlightedCell:(NSCell *)cell;
@end


@interface NSObject (LPEmoticonMatrixDelegate)
- (void)emoticonMatrix:(LPEmoticonMatrix *)matrix highlightedCellDidChange:(NSCell *)newlyHighlightedCell;
@end
