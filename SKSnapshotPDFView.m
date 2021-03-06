//
//  SKSnapshotPDFView.m
//  Skim
//
//  Created by Adam Maxwell on 07/23/05.
/*
 This software is Copyright (c) 2005-2017
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
 contributors may be used to endorse or promote products derived
 from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS ORd SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SKSnapshotPDFView.h"
#import "NSResponder_SKExtensions.h"
#import "NSEvent_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "SKMainDocument.h"
#import "SKPDFSynchronizer.h"
#import "SKStringConstants.h"
#import "PDFSelection_SKExtensions.h"
#import "PDFView_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSMenu_SKExtensions.h"


@interface SKSnapshotPDFView (SKPrivate)

- (void)resetAutoFitRectIfNeeded;

- (void)scalePopUpAction:(id)sender;

- (void)setAutoFits:(BOOL)newAuto adjustPopup:(BOOL)flag;
- (void)setScaleFactor:(CGFloat)factor adjustPopup:(BOOL)flag;

- (void)handlePDFViewFrameChangedNotification:(NSNotification *)notification;
- (void)handlePDFContentViewFrameChangedNotification:(NSNotification *)notification;
- (void)handlePDFContentViewFrameChangedDelayedNotification:(NSNotification *)notification;

- (void)handlePDFViewScaleChangedNotification:(NSNotification *)notification;

@end

@implementation SKSnapshotPDFView

@synthesize autoFits;
@dynamic scalePopUpButton;

#define SKPDFContentViewChangedNotification @"SKPDFContentViewChangedNotification"

static NSString *SKDefaultScaleMenuLabels[] = {@"Auto", @"10%", @"20%", @"25%", @"35%", @"50%", @"60%", @"71%", @"85%", @"100%", @"120%", @"141%", @"170%", @"200%", @"300%", @"400%", @"600%", @"800%", @"1000%", @"1200%", @"1400%", @"1700%", @"2000%"};
static CGFloat SKDefaultScaleMenuFactors[] = {0.0, 0.1, 0.2, 0.25, 0.35, 0.5, 0.6, 0.71, 0.85, 1.0, 1.2, 1.41, 1.7, 2.0, 3.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0, 17.0, 20.0};

#define SKMinDefaultScaleMenuFactor (SKDefaultScaleMenuFactors[1])
#define SKDefaultScaleMenuFactorsCount (sizeof(SKDefaultScaleMenuFactors) / sizeof(CGFloat))

#define CONTROL_FONT_SIZE 10.0
#define CONTROL_HEIGHT 15.0
#define CONTROL_WIDTH_OFFSET 20.0

#pragma mark Popup button

- (void)commonInitialization {
    scalePopUpButton = nil;
    autoFitPage = nil;
    autoFitRect = NSZeroRect;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePDFViewFrameChangedNotification:)
                                                 name:NSViewFrameDidChangeNotification object:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePDFViewFrameChangedNotification:) 
                                                 name:NSViewBoundsDidChangeNotification object:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePDFContentViewFrameChangedNotification:) 
                                                 name:NSViewBoundsDidChangeNotification object:[[self scrollView] contentView]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePDFContentViewFrameChangedDelayedNotification:)
                                                 name:SKPDFContentViewChangedNotification object:self];
    if ([PDFView instancesRespondToSelector:@selector(magnifyWithEvent:)] == NO || [PDFView instanceMethodForSelector:@selector(magnifyWithEvent:)] == [NSView instanceMethodForSelector:@selector(magnifyWithEvent:)])
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePDFViewScaleChangedNotification:)
                                                     name:PDFViewScaleChangedNotification object:self];
}

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self commonInitialization];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        [self commonInitialization];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    SKDESTROY(scalePopUpButton);
    [super dealloc];
}

- (NSPopUpButton *)scalePopUpButton {
    
    if (scalePopUpButton == nil) {
        
        NSScrollView *scrollView = [self scrollView];
        [scrollView setHasHorizontalScroller:YES];
        
        // create it        
        scalePopUpButton = [[NSPopUpButton allocWithZone:[self zone]] initWithFrame:NSMakeRect(0.0, 0.0, 1.0, 1.0) pullsDown:NO];
        
        [[scalePopUpButton cell] setControlSize:NSSmallControlSize];
		[scalePopUpButton setBordered:NO];
		[scalePopUpButton setEnabled:YES];
		[scalePopUpButton setRefusesFirstResponder:YES];
		[[scalePopUpButton cell] setUsesItemFromMenu:YES];
        
        // set a suitable font, the control size is 0, 1 or 2
        [scalePopUpButton setFont:[NSFont toolTipsFontOfSize:CONTROL_FONT_SIZE]];
		
        NSUInteger cnt, numberOfDefaultItems = SKDefaultScaleMenuFactorsCount;
        id curItem;
        NSString *label;
        CGFloat width, maxWidth = 0.0;
        NSSize size = NSMakeSize(1000.0, 1000.0);
        NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:[scalePopUpButton font], NSFontAttributeName, nil];
        NSUInteger maxIndex = 0;
        
        // fill it
        for (cnt = 0; cnt < numberOfDefaultItems; cnt++) {
            label = [[NSBundle mainBundle] localizedStringForKey:SKDefaultScaleMenuLabels[cnt] value:@"" table:@"ZoomValues"];
            width = NSWidth([label boundingRectWithSize:size options:0 attributes:attrs]);
            if (width > maxWidth) {
                maxWidth = width;
                maxIndex = cnt;
            }
            [scalePopUpButton addItemWithTitle:label];
            curItem = [scalePopUpButton itemAtIndex:cnt];
            [curItem setRepresentedObject:(SKDefaultScaleMenuFactors[cnt] > 0.0 ? [NSNumber numberWithDouble:SKDefaultScaleMenuFactors[cnt]] : nil)];
        }
        
        // Make sure the popup is big enough to fit the largest cell
        [scalePopUpButton selectItemAtIndex:maxIndex];
        [scalePopUpButton sizeToFit];
        [scalePopUpButton setFrameSize:NSMakeSize(NSWidth([scalePopUpButton frame]) - CONTROL_WIDTH_OFFSET, CONTROL_HEIGHT)];
        
        // select the appropriate item, adjusting the scaleFactor if necessary
        if([self autoFits])
            [self setScaleFactor:0.0 adjustPopup:YES];
        else
            [self setScaleFactor:[self scaleFactor] adjustPopup:YES];
        
        // hook it up
        [scalePopUpButton setTarget:self];
        [scalePopUpButton setAction:@selector(scalePopUpAction:)];
        
		// don't let it become first responder
		[scalePopUpButton setRefusesFirstResponder:YES];
        
    }
    
    return scalePopUpButton;
}

- (void)handlePDFViewFrameChangedNotification:(NSNotification *)notification {
    if ([self autoFits]) {
        NSView *clipView = [[self scrollView] contentView];
        NSRect rect = [self convertRect:[clipView visibleRect] fromView:clipView];
        BOOL scaleWidth = NSWidth(rect) / NSHeight(rect) < NSWidth(autoFitRect) / NSHeight(autoFitRect);
        CGFloat factor = scaleWidth ? NSWidth(rect) / NSWidth(autoFitRect) : NSHeight(rect) / NSHeight(autoFitRect);
        NSRect viewRect = scaleWidth ? NSInsetRect(autoFitRect, 0.0, 0.5 * (NSHeight(autoFitRect) - NSHeight(rect) / factor)) : NSInsetRect(autoFitRect, 0.5 * (NSWidth(autoFitRect) - NSWidth(rect) / factor), 0.0);
        [super setScaleFactor:factor];
        [self goToRect:viewRect onPage:autoFitPage];
    }
}

- (void)handlePDFContentViewFrameChangedDelayedNotification:(NSNotification *)notification {
    if ([self inLiveResize] == NO && [[self window] isZoomed] == NO)
        [self resetAutoFitRectIfNeeded];
}

- (void)handlePDFContentViewFrameChangedNotification:(NSNotification *)notification {
    if ([self inLiveResize] == NO && [[self window] isZoomed] == NO) {
        NSNotification *note = [NSNotification notificationWithName:SKPDFContentViewChangedNotification object:self];
        [[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostWhenIdle coalesceMask:NSNotificationCoalescingOnName forModes:nil];
    }
}

- (void)handlePDFViewScaleChangedNotification:(NSNotification *)notification {
    if ([self autoFits] == NO)
        [self setScaleFactor:fmax([self scaleFactor], SKMinDefaultScaleMenuFactor) adjustPopup:YES];
}

- (void)resetAutoFitRectIfNeeded {
    if ([self autoFits]) {
        NSView *clipView = [[self scrollView] contentView];
        autoFitPage = [self currentPage];
        autoFitRect = [self convertRect:[self convertRect:[clipView visibleRect] fromView:clipView] toPage:autoFitPage];
    }
}

- (void)scalePopUpAction:(id)sender {
    NSNumber *selectedFactorObject = [[sender selectedItem] representedObject];
    if(selectedFactorObject)
        [self setScaleFactor:[selectedFactorObject doubleValue] adjustPopup:NO];
    else
        [self setAutoFits:YES adjustPopup:NO];
}

- (void)setAutoFits:(BOOL)newAuto {
    [self setAutoFits:newAuto adjustPopup:YES];
}

- (void)setAutoFits:(BOOL)newAuto adjustPopup:(BOOL)flag {
    if (autoFits != newAuto) {
        autoFits = newAuto;
        if (autoFits) {
            [super setAutoScales:NO];
            [self resetAutoFitRectIfNeeded];
            if (flag)
                [scalePopUpButton selectItemAtIndex:0];
        } else {
            autoFitPage = nil;
            autoFitRect = NSZeroRect;
            if (flag)
                [self setScaleFactor:[self scaleFactor] adjustPopup:flag];
        }
    }
}

- (NSUInteger)lowerIndexForScaleFactor:(CGFloat)scaleFactor {
    NSUInteger i, count = SKDefaultScaleMenuFactorsCount;
    for (i = count - 1; i > 0; i--) {
        if (scaleFactor * 1.01 > SKDefaultScaleMenuFactors[i])
            return i;
    }
    return 1;
}

- (NSUInteger)upperIndexForScaleFactor:(CGFloat)scaleFactor {
    NSUInteger i, count = SKDefaultScaleMenuFactorsCount;
    for (i = 1; i < count; i++) {
        if (scaleFactor * 0.99 < SKDefaultScaleMenuFactors[i])
            return i;
    }
    return count - 1;
}

- (NSUInteger)indexForScaleFactor:(CGFloat)scaleFactor {
    NSUInteger lower = [self lowerIndexForScaleFactor:scaleFactor], upper = [self upperIndexForScaleFactor:scaleFactor];
    if (upper > lower && scaleFactor < 0.5 * (SKDefaultScaleMenuFactors[lower] + SKDefaultScaleMenuFactors[upper]))
        return lower;
    return upper;
}

- (void)setScaleFactor:(CGFloat)newScaleFactor {
	[self setScaleFactor:newScaleFactor adjustPopup:YES];
}

- (void)setScaleFactor:(CGFloat)newScaleFactor adjustPopup:(BOOL)flag {
	if (flag) {
		NSUInteger i = [self indexForScaleFactor:newScaleFactor];
        [scalePopUpButton selectItemAtIndex:i];
        newScaleFactor = SKDefaultScaleMenuFactors[i];
    }
    if ([self autoFits])
        [self setAutoFits:NO adjustPopup:NO];
    [super setScaleFactor:newScaleFactor];
}

- (void)setAutoScales:(BOOL)newAuto {}

- (IBAction)zoomIn:(id)sender{
    if([self autoFits]){
        [super zoomIn:sender];
        [self setAutoFits:NO adjustPopup:YES];
    }else{
        NSUInteger numberOfDefaultItems = SKDefaultScaleMenuFactorsCount;
        NSUInteger i = [self lowerIndexForScaleFactor:[self scaleFactor]];
        if (i < numberOfDefaultItems - 1) i++;
        [self setScaleFactor:SKDefaultScaleMenuFactors[i]];
    }
}

- (IBAction)zoomOut:(id)sender{
    if([self autoFits]){
        [super zoomOut:sender];
        [self setAutoFits:NO adjustPopup:YES];
    }else{
        NSUInteger i = [self upperIndexForScaleFactor:[self scaleFactor]];
        if (i > 1) i--;
        [self setScaleFactor:SKDefaultScaleMenuFactors[i]];
    }
}

- (BOOL)canZoomIn{
    if ([super canZoomIn] == NO)
        return NO;
    NSUInteger numberOfDefaultItems = SKDefaultScaleMenuFactorsCount;
    NSUInteger i = [self lowerIndexForScaleFactor:[self scaleFactor]];
    return i < numberOfDefaultItems - 1;
}

- (BOOL)canZoomOut{
    if ([super canZoomOut] == NO)
        return NO;
    NSUInteger i = [self upperIndexForScaleFactor:[self scaleFactor]];
    return i > 1;
}

- (BOOL)canGoBack {
    if ([self respondsToSelector:@selector(currentHistoryIndex)] && minHistoryIndex > 0)
        return minHistoryIndex < [self currentHistoryIndex];
    else
        return [super canGoBack];
}

- (void)resetHistory {
    if ([self respondsToSelector:@selector(currentHistoryIndex)])
        minHistoryIndex = [self currentHistoryIndex];
}

- (void)goToPage:(PDFPage *)aPage {
    [super goToPage:aPage];
    [self resetAutoFitRectIfNeeded];
}

- (void)doAutoFit:(id)sender {
    [self setAutoFits:YES];
}

- (void)doActualSize:(id)sender {
    [self setScaleFactor:1.0];
}

- (void)doPhysicalSize:(id)sender {
    [self setPhysicalScaleFactor:1.0];
}

// we don't want to steal the printDocument: action from the responder chain
- (void)printDocument:(id)sender{}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return aSelector != @selector(printDocument:) && [super respondsToSelector:aSelector];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    static NSSet *selectionActions = nil;
    if (selectionActions == nil)
        selectionActions = [[NSSet alloc] initWithObjects:@"copy:", @"_searchInSpotlight:", @"_searchInGoogle:", @"_searchInDictionary:", nil];
    NSMenu *menu = [super menuForEvent:theEvent];
    
    [self setCurrentSelection:nil];
    while ([menu numberOfItems]) {
        NSMenuItem *item = [menu itemAtIndex:0];
        if ([item isSeparatorItem] || [self validateMenuItem:item] == NO || [selectionActions containsObject:NSStringFromSelector([item action])])
            [menu removeItemAtIndex:0];
        else
            break;
    }
    
    NSInteger i = [menu indexOfItemWithTarget:self andAction:NSSelectorFromString(@"_setAutoSize:")];
    if (i != -1)
        [[menu itemAtIndex:i] setAction:@selector(doAutoFit:)];
    i = [menu indexOfItemWithTarget:self andAction:NSSelectorFromString(@"_setActualSize:")];
    if (i != -1) {
        [[menu itemAtIndex:i] setAction:@selector(doActualSize:)];
        NSMenuItem *item = [menu insertItemWithTitle:NSLocalizedString(@"Physical Size", @"Menu item title") action:@selector(doPhysicalSize:) target:self atIndex:i + 1];
        [item setKeyEquivalentModifierMask:NSAlternateKeyMask];
        [item setAlternate:YES];
    }
    
    return menu;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(doAutoFit:)) {
        [menuItem setState:[self autoFits] ? NSOnState : NSOffState];
        return YES;
    } else if ([menuItem action] == @selector(doActualSize:)) {
        [menuItem setState:fabs([self scaleFactor] - 1.0) < 0.1 ? NSOnState : NSOffState];
        return YES;
    } else if ([menuItem action] == @selector(doPhysicalSize:)) {
        [menuItem setState:([self autoScales] || fabs([self physicalScaleFactor] - 1.0 ) > 0.01) ? NSOffState : NSOnState];
        return YES;
    } else if ([[SKSnapshotPDFView superclass] instancesRespondToSelector:_cmd]) {
        return [super validateMenuItem:menuItem];
    }
    return YES;
}

#pragma mark Gestures

- (void)beginGestureWithEvent:(NSEvent *)theEvent {
    if ([[SKSnapshotPDFView superclass] instancesRespondToSelector:_cmd])
        [super beginGestureWithEvent:theEvent];
    startScale = [self scaleFactor];
}

- (void)endGestureWithEvent:(NSEvent *)theEvent {
    if (fabs(startScale - [self scaleFactor]) > 0.001)
        [self setScaleFactor:fmax([self scaleFactor], SKMinDefaultScaleMenuFactor) adjustPopup:YES];
    if ([[SKSnapshotPDFView superclass] instancesRespondToSelector:_cmd])
        [super endGestureWithEvent:theEvent];
}

- (void)magnifyWithEvent:(NSEvent *)theEvent {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisablePinchZoomKey] == NO && [theEvent respondsToSelector:@selector(magnification)]) {
        if ([theEvent respondsToSelector:@selector(phase)] && [theEvent phase] == NSEventPhaseBegan)
            startScale = [self scaleFactor];
        CGFloat magnifyFactor = (1.0 + fmax(-0.5, fmin(1.0 , [theEvent magnification])));
        [super setScaleFactor:magnifyFactor * [self scaleFactor]];
        if ([theEvent respondsToSelector:@selector(phase)] && ([theEvent phase] == NSEventPhaseEnded || [theEvent phase] == NSEventPhaseCancelled) && fabs(startScale - [self scaleFactor]) > 0.001)
            [self setScaleFactor:fmax([self scaleFactor], SKMinDefaultScaleMenuFactor) adjustPopup:YES];
    }
}

#pragma mark Dragging

- (void)mouseDown:(NSEvent *)theEvent{
    [[self window] makeFirstResponder:self];
	
    if ([theEvent standardModifierFlags] == (NSCommandKeyMask | NSShiftKeyMask)) {
        
        [self doPdfsyncWithEvent:theEvent];
        
    } else {
        
        [self doDragWithEvent:theEvent];
        
    }
}

- (void)setCursorForAreaOfInterest:(PDFAreaOfInterest)area {
    if ([NSEvent standardModifierFlags] == (NSCommandKeyMask | NSShiftKeyMask))
        [[NSCursor arrowCursor] set];
    else
        [[NSCursor openHandCursor] set];
}

@end
