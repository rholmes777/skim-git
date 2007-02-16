//
//  SKNavigationWindow.h
//  Skim
//
//  Created by Christiaan Hofman on 12/19/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PDFView, SKNavigationToolTipView, SKNavigationButton;

@interface SKNavigationWindow : NSWindow {
    NSMutableArray *buttons;
    NSViewAnimation *animation;
}
- (id)initWithPDFView:(PDFView *)pdfView;
- (void)moveToScreen:(NSScreen *)screen;
- (void)hide;
@end


@interface SKNavigationContentView : NSView
@end


@interface SKNavigationToolTipWindow : NSWindow {
    SKNavigationToolTipView *toolTipView;
}
+ (id)sharedToolTipWindow;
- (void)showToolTip:(NSString *)toolTip forView:(NSView *)view;
@end

@interface SKNavigationToolTipView : NSView {
    NSString *stringValue;
}
- (NSString *)stringValue;
- (void)setStringValue:(NSString *)newStringValue;
- (NSAttributedString *)attributedStringValue;
- (void)sizeToFit;
@end


@interface SKNavigationButton : NSButton {
    NSString *toolTip;
    NSString *alternateToolTip;
}
- (NSString *)currentToolTip;
- (NSString *)alternateToolTip;
- (void)setAlternateToolTip:(NSString *)string;
@end


@interface SKNavigationButtonCell : NSButtonCell
- (NSBezierPath *)pathWithFrame:(NSRect)cellFrame;
@end


@interface SKNavigationNextButton : SKNavigationButton
@end

@interface SKNavigationNextButtonCell : SKNavigationButtonCell
@end


@interface SKNavigationPreviousButton : SKNavigationButton
@end

@interface SKNavigationPreviousButtonCell : SKNavigationButtonCell
@end


@interface SKNavigationZoomButton : SKNavigationButton
@end

@interface SKNavigationZoomButtonCell : SKNavigationButtonCell
@end


@interface SKNavigationCloseButton : SKNavigationButton
@end

@interface SKNavigationCloseButtonCell : SKNavigationButtonCell
@end


@interface SKNavigationSeparatorButton : SKNavigationButton
@end

@interface SKNavigationSeparatorButtonCell : SKNavigationButtonCell
@end
