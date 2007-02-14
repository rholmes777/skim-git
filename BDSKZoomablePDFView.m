//
//  BDSKZoomablePDFView.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/23/05.
/*
 This software is Copyright (c) 2005,2006
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
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "BDSKZoomablePDFView.h"
#import "BDSKHeaderPopUpButton.h"

static void _OBRegisterMethod(IMP methodImp, Class class, const char *methodTypes, SEL selector);
IMP OBRegisterInstanceMethodWithSelector(Class aClass, SEL oldSelector, SEL newSelector);
IMP OBReplaceMethodImplementation(Class aClass, SEL oldSelector, IMP newImp);
IMP OBReplaceMethodImplementationWithSelector(Class aClass, SEL oldSelector, SEL newSelector);


@interface NSScrollView (BDSKZoomablePDFViewExtensions) 
- (void)replacementDealloc;
- (BOOL)replacementHasHorizontalScroller;
- (void)replacementSetHasHorizontalScroller:(BOOL)flag;

// new API allows ignoring PDFView's attempts to remove the horizontal scroller
- (void)setAlwaysHasHorizontalScroller:(BOOL)flag;

@end

@implementation NSScrollView (BDSKZoomablePDFViewExtensions)

static IMP originalSetHasHorizontalScroller = NULL;
static BOOL (*originalHasHorizontalScroller)(id, SEL) = NULL;
static IMP originalDealloc = NULL;

static CFMutableSetRef nonretainedScrollviews = NULL;

+ (void)load{
    originalSetHasHorizontalScroller = OBReplaceMethodImplementationWithSelector(self, @selector(setHasHorizontalScroller:), @selector(replacementSetHasHorizontalScroller:));
    originalHasHorizontalScroller = (typeof(originalHasHorizontalScroller))OBReplaceMethodImplementationWithSelector(self, @selector(hasHorizontalScroller), @selector(replacementHasHorizontalScroller));
    originalDealloc = OBReplaceMethodImplementationWithSelector(self, @selector(dealloc), @selector(replacementDealloc));
    
    // set doesn't retain, so no retain cycles; pointer equality used to compare views
    nonretainedScrollviews = CFSetCreateMutable(CFAllocatorGetDefault(), 0, NULL);
}

- (void)replacementDealloc;
{
    CFSetRemoveValue(nonretainedScrollviews, self);
    originalDealloc(self, _cmd);
}

- (void)setAlwaysHasHorizontalScroller:(BOOL)flag;
{
    if (flag) {
        CFSetAddValue(nonretainedScrollviews, self);
        [self setHasHorizontalScroller:YES];
    } else {
        CFSetRemoveValue(nonretainedScrollviews, self);
    }
}

- (void)replacementSetHasHorizontalScroller:(BOOL)flag;
{
    if (CFSetContainsValue(nonretainedScrollviews, self))
        flag = YES;
    originalSetHasHorizontalScroller(self, _cmd, flag);
}

- (BOOL)replacementHasHorizontalScroller;
{
    return CFSetContainsValue(nonretainedScrollviews, self) ? YES : originalHasHorizontalScroller(self, _cmd);
}

@end

@interface PDFView (BDSKApplePrivateOverride)
- (void)adjustScrollbars:(id)obj;
@end

@implementation BDSKZoomablePDFView

/* For genstrings:
    NSLocalizedStringFromTable(@"10%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"25%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"50%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"75%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"100%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"128%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"200%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"400%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"800%", @"ZoomValues", @"Zoom popup entry")
*/   
static NSString *BDSKDefaultScaleMenuLabels[] = {/* @"Set...", */ @"Auto", @"10%", @"25%", @"50%", @"75%", @"100%", @"128%", @"150%", @"200%", @"400%", @"800%"};
static float BDSKDefaultScaleMenuFactors[] = {/* 0.0, */ 0, 0.1, 0.25, 0.5, 0.75, 1.0, 1.28, 1.5, 2.0, 4.0, 8.0};
static float BDSKScaleMenuFontSize = 11.0;

#pragma mark Instance methods

- (id)initWithFrame:(NSRect)rect {
    if (self = [super initWithFrame:rect]) {
        pasteboardInfo = [[NSMutableDictionary alloc] initWithCapacity:2];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        pasteboardInfo = [[NSMutableDictionary alloc] initWithCapacity:2];
    }
    return self;
}

- (void)dealloc{
    [pasteboardInfo release];
    [super dealloc];
}

#pragma mark Copying

// used to cache the selection info and document for lazy copying
- (void)updatePasteboardInfo;
{    
    PDFSelection *theSelection = [self currentSelection];
    if(!theSelection)
        theSelection = [[self document] selectionForEntireDocument];
    
    [pasteboardInfo setValue:theSelection forKey:@"selection"];
    [pasteboardInfo setValue:[self document] forKey:@"document"];
    [pasteboardInfo setValue:[self currentPage] forKey:@"page"];
}

// override so we can put the entire document on the pasteboard if there is no selection
- (void)copy:(id)sender;
{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    [pboard declareTypes:[NSArray arrayWithObjects:NSPDFPboardType, NSStringPboardType, NSRTFPboardType, nil] owner:self];
    [self updatePasteboardInfo];
}

- (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type;
{    
    PDFSelection *theSelection = [pasteboardInfo valueForKey:@"selection"];
    PDFDocument *theDocument = [pasteboardInfo valueForKey:@"document"];
    PDFPage *thePage = [pasteboardInfo valueForKey:@"page"];
    
    // use a private type to signal that we need to provide a page as PDF
    if([type isEqualToString:NSPDFPboardType] && [[sender types] containsObject:@"BDSKPrivatePDFPageDataPboardType"]){
        [sender setData:[thePage dataRepresentation] forType:type];
    } else if([type isEqualToString:NSPDFPboardType]){ 
        // write the whole document
        [sender setData:[theDocument dataRepresentation] forType:type];
    } else if([type isEqualToString:NSStringPboardType]){
        [sender setString:[theSelection string] forType:type];
    } else if([type isEqualToString:NSRTFPboardType]){
        NSAttributedString *attrString = [theSelection attributedString];
        [sender setData:[attrString RTFFromRange:NSMakeRange(0, [attrString length]) documentAttributes:nil] forType:type];
    } else NSBeep();
}

- (void)copyAsPDF:(id)sender;
{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    [pboard declareTypes:[NSArray arrayWithObjects:NSPDFPboardType, @"BDSKPrivatePDFPageDataPboardType", nil] owner:self];
    [self updatePasteboardInfo];
}

- (void)copyAsText:(id)sender;
{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    [pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NSRTFPboardType, nil] owner:self];
    [self updatePasteboardInfo];
}

- (void)copyPDFPage:(id)sender;
{
    [self copyAsPDF:nil];
}

- (void)saveDocumentSheetDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode  contextInfo:(void  *)contextInfo;
{
    NSError *error = nil;
    if(returnCode == NSOKButton){
        // -[PDFDocument writeToURL:] returns YES even if you don't have write permission, so we'll use NSData rdar://problem/4475062
        NSData *data = [[self document] dataRepresentation];
        
        if([data writeToURL:[sheet URL] options:NSAtomicWrite error:&error] == NO){
            [sheet orderOut:nil];
            [self presentError:error];
        }
    }
}
    
- (void)saveDocumentAs:(id)sender;
{
    NSString *name = [[[[self document] documentURL] path] lastPathComponent];
    [[NSSavePanel savePanel] beginSheetForDirectory:nil file:(name ? name : NSLocalizedString(@"Untitled.pdf", @"Default file name for saved PDF")) modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(saveDocumentSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent;
{
    NSMenu *menu = [super menuForEvent:theEvent];
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Copy Document as PDF", @"Menu item title") action:@selector(copyAsPDF:) keyEquivalent:@""];
    [menu addItem:item];
    [item release];
    
    item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Copy Page as PDF", @"Menu item title") action:@selector(copyPDFPage:) keyEquivalent:@""];
    [menu addItem:item];
    [item release];

    NSString *title = (nil == [self currentSelection]) ? NSLocalizedString(@"Copy All Text", @"Menu item title") : NSLocalizedString(@"Copy Selected Text", @"Menu item title");
    
    item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:title action:@selector(copyAsText:) keyEquivalent:@""];
    [menu addItem:item];
    [item release];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Save PDF As", @"Menu item title") stringByAppendingFormat:@"%C", 0x2026] action:@selector(saveDocumentAs:) keyEquivalent:@""];
    [menu addItem:item];
    [item release];

    return menu;
}
    
#pragma mark Popup button

- (void)makeScalePopUpButton {
    
    if (scalePopUpButton == nil) {
        
        NSScrollView *scrollView = [self scrollView];
        [scrollView setAlwaysHasHorizontalScroller:YES];

        unsigned cnt, numberOfDefaultItems = (sizeof(BDSKDefaultScaleMenuLabels) / sizeof(NSString *));
        id curItem;

        // create it        
        scalePopUpButton = [[BDSKHeaderPopUpButton allocWithZone:[self zone]] initWithFrame:NSMakeRect(0.0, 0.0, 1.0, 1.0) pullsDown:NO];
        
        NSControlSize controlSize = [[scrollView horizontalScroller] controlSize];
        [[scalePopUpButton cell] setControlSize:controlSize];
		
        // fill it
        for (cnt = 0; cnt < numberOfDefaultItems; cnt++) {
            [scalePopUpButton addItemWithTitle:NSLocalizedStringFromTable(BDSKDefaultScaleMenuLabels[cnt], @"ZoomValues", nil)];
            curItem = [scalePopUpButton itemAtIndex:cnt];
            [curItem setRepresentedObject:(BDSKDefaultScaleMenuFactors[cnt] > 0.0 ? [NSNumber numberWithFloat:BDSKDefaultScaleMenuFactors[cnt]] : nil)];
        }
        // select the appropriate item, adjusting the scaleFactor if necessary
        if([self autoScales])
            [self setScaleFactor:0.0 adjustPopup:YES];
        else
            [self setScaleFactor:[self scaleFactor] adjustPopup:YES];

        // hook it up
        [scalePopUpButton setTarget:self];
        [scalePopUpButton setAction:@selector(scalePopUpAction:)];

        // set a suitable font, the control size is 0, 1 or 2
        [scalePopUpButton setFont:[NSFont toolTipsFontOfSize: BDSKScaleMenuFontSize - controlSize]];

        // Make sure the popup is big enough to fit the cells.
        [scalePopUpButton sizeToFit];

		// don't let it become first responder
		[scalePopUpButton setRefusesFirstResponder:YES];

        // put it in the scrollview
        [scrollView addSubview:scalePopUpButton];
        [scalePopUpButton release];
    }
}

- (void)drawRect:(NSRect)rect {
    [self layoutScrollView];
    [super drawRect:rect];

    if ([scalePopUpButton superview]) {
        NSRect shadowRect = [scalePopUpButton frame];
        shadowRect.origin.x -= 1.0;
        shadowRect.origin.y -= 1.0;
        shadowRect.size.width += 1.0;
        shadowRect.size.height += 1.0;
		shadowRect = [self convertRect:shadowRect fromView:[scalePopUpButton superview]];
        if (NSIntersectsRect(rect, shadowRect)) {
            [[NSColor lightGrayColor] set];
            NSRectFill(shadowRect);
        }
    }
}

- (void)scalePopUpAction:(id)sender {
    NSNumber *selectedFactorObject = [[sender selectedCell] representedObject];
    if(!selectedFactorObject)
        [super setAutoScales:YES];
    else
        [self setScaleFactor:[selectedFactorObject floatValue] adjustPopup:NO];
}

- (void)setScaleFactor:(float)newScaleFactor {
	[self setScaleFactor:newScaleFactor adjustPopup:YES];
}

- (void)setScaleFactor:(float)newScaleFactor adjustPopup:(BOOL)flag {
    
	if (flag) {
		unsigned cnt = 0, numberOfDefaultItems = (sizeof(BDSKDefaultScaleMenuFactors) / sizeof(float));
		
		// We only work with some preset zoom values, so choose one of the appropriate values (Fudge a little for floating point == to work)
		while (cnt < numberOfDefaultItems && newScaleFactor * .99 > BDSKDefaultScaleMenuFactors[cnt]) cnt++;
		if (cnt == numberOfDefaultItems) cnt--;
		[scalePopUpButton selectItemAtIndex:cnt];
		newScaleFactor = BDSKDefaultScaleMenuFactors[cnt];
    }
    
    if(fabs(newScaleFactor) < 0.01)
        [self setAutoScales:YES];
    else
        [super setScaleFactor:newScaleFactor];
}

- (void)setAutoScales:(BOOL)newAuto {
    [super setAutoScales:newAuto];
    
    if(newAuto)
		[scalePopUpButton selectItemAtIndex:0];
}

- (IBAction)zoomIn:(id)sender{
    if([self autoScales]){
        [super zoomIn:sender];
    }else{
        int cnt = 0, numberOfDefaultItems = (sizeof(BDSKDefaultScaleMenuFactors) / sizeof(float));
        float scaleFactor = [self scaleFactor];
        
        // We only work with some preset zoom values, so choose one of the appropriate values (Fudge a little for floating point == to work)
        while (cnt < numberOfDefaultItems && scaleFactor * .99 > BDSKDefaultScaleMenuFactors[cnt]) cnt++;
        cnt++;
        while (cnt >= numberOfDefaultItems) cnt--;
        [self setScaleFactor:BDSKDefaultScaleMenuFactors[cnt]];
    }
}

- (IBAction)zoomOut:(id)sender{
    if([self autoScales]){
        [super zoomOut:sender];
    }else{
        int cnt = 0, numberOfDefaultItems = (sizeof(BDSKDefaultScaleMenuFactors) / sizeof(float));
        float scaleFactor = [self scaleFactor];
        
        // We only work with some preset zoom values, so choose one of the appropriate values (Fudge a little for floating point == to work)
        while (cnt < numberOfDefaultItems && scaleFactor * .99 > BDSKDefaultScaleMenuFactors[cnt]) cnt++;
        cnt--;
        if (cnt < 0) cnt++;
        [self setScaleFactor:BDSKDefaultScaleMenuFactors[cnt]];
    }
}

- (BOOL)canZoomIn{
    if ([super canZoomIn] == NO)
        return NO;
    if([self autoScales])   
        return YES;
    unsigned cnt = 0, numberOfDefaultItems = (sizeof(BDSKDefaultScaleMenuFactors) / sizeof(float));
    float scaleFactor = [self scaleFactor];
    // We only work with some preset zoom values, so choose one of the appropriate values (Fudge a little for floating point == to work)
    while (cnt < numberOfDefaultItems && scaleFactor * .99 > BDSKDefaultScaleMenuFactors[cnt]) cnt++;
    return cnt < numberOfDefaultItems - 1;
}

- (BOOL)canZoomOut{
    if ([super canZoomOut] == NO)
        return NO;
    if([self autoScales])   
        return YES;
    unsigned cnt = 0, numberOfDefaultItems = (sizeof(BDSKDefaultScaleMenuFactors) / sizeof(float));
    float scaleFactor = [self scaleFactor];
    // We only work with some preset zoom values, so choose one of the appropriate values (Fudge a little for floating point == to work)
    while (cnt < numberOfDefaultItems && scaleFactor * .99 > BDSKDefaultScaleMenuFactors[cnt]) cnt++;
    return cnt > 0;
}

#pragma mark Scrollview

- (NSScrollView *)scrollView;
{
    return [[self documentView] enclosingScrollView];
}

- (void)setScrollerSize:(NSControlSize)controlSize;
{
    NSScrollView *scrollView = [[self documentView] enclosingScrollView];
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setHasVerticalScroller:YES];
    [[scrollView horizontalScroller] setControlSize:controlSize];
    [[scrollView verticalScroller] setControlSize:controlSize];
	if(scalePopUpButton){
		[[scalePopUpButton cell] setControlSize:controlSize];
        [scalePopUpButton setFont:[NSFont toolTipsFontOfSize: BDSKScaleMenuFontSize - controlSize]];
	}
}

- (void)adjustScrollbars:(id)obj;
{
    // this private method is only called by PDFView, so super must implement it if it's called
    [super adjustScrollbars:obj];
    [self layoutScrollView];
    // be careful here; check the comment in -layoutScrollView before changing anything
}

- (void)layoutScrollView;
{
    NSScrollView *scrollView = [self scrollView];
    
    // Don't force scroller display on the scrollview; PDFView apparently uses a timer to call adjustScrollbars:, and preventing autohide will cause an endless loop if you zoom so that the vertical scroller is not displayed (regardless of whether we swizzle -[NSScrollView tile] or override -[PDFView adjustScrollbars:]).  Therefore, we always display the button,  even though it looks stupid without the scrollers.  Since it's not really readable anyway at 25%, this probably isn't a big deal, since this isn't supposed to be a thumbnail view.
    
    NSControlSize controlSize = NSRegularControlSize;
    
    if ([scrollView hasHorizontalScroller])
        controlSize = [[scrollView horizontalScroller] controlSize];
    else if ([scrollView hasVerticalScroller])
        controlSize = [[scrollView verticalScroller] controlSize];
    
    float scrollerWidth = [NSScroller scrollerWidthForControlSize:controlSize];
    
    if (!scalePopUpButton) [self makeScalePopUpButton];
    
    NSRect horizScrollerFrame, buttonFrame;
    buttonFrame = [scalePopUpButton frame];
    
    NSScroller *horizScroller = [scrollView horizontalScroller];
    
    if (horizScroller) {
        horizScrollerFrame = [horizScroller frame];
        
        // Now we'll just adjust the horizontal scroller size and set the button size and location.
        // Set it based on our frame, not the scroller's frame, since this gets called repeatedly.
        horizScrollerFrame.size.width = NSWidth([scrollView frame]) - NSWidth(buttonFrame) - scrollerWidth - 1.0;
        [horizScroller setFrameSize:horizScrollerFrame.size];
    }
    buttonFrame.size.height = scrollerWidth - 1.0;

    // @@ resolution independence: 2.0 may not work
    if ([scrollView isFlipped]) {
        buttonFrame.origin.x = NSMaxX([scrollView frame]) - scrollerWidth - NSWidth(buttonFrame);
        buttonFrame.origin.y = NSMaxY([scrollView frame]) - NSHeight(buttonFrame);            
    }
    else {
        buttonFrame.origin.x = NSMaxX([scrollView frame]) - scrollerWidth - NSWidth(buttonFrame);
        buttonFrame.origin.y = NSMinY([scrollView frame]);
    }
    [scalePopUpButton setFrame:buttonFrame];
}

#pragma mark Dragging

- (void)mouseDown:(NSEvent *)theEvent{
    [[NSCursor closedHandCursor] push];
}

- (void)mouseUp:(NSEvent *)theEvent{
    [NSCursor pop];
}

- (void)mouseMoved:(NSEvent *)theEvent {
    [[NSCursor openHandCursor] set];
}

- (void)mouseDragged:(NSEvent *)theEvent {
    [self dragWithEvent:theEvent];	
    // ??? PDFView's delayed layout seems to reset the cursor to an arrow
    [self performSelector:@selector(mouseMoved:) withObject:theEvent afterDelay:0];
}

- (void)dragWithEvent:(NSEvent *)theEvent {
	NSPoint initialLocation = [theEvent locationInWindow];
	NSRect visibleRect = [[self documentView] visibleRect];
	BOOL keepGoing = YES;
	
	while (keepGoing) {
		theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
		switch ([theEvent type]) {
			case NSLeftMouseDragged:
            {
				NSPoint	newLocation;
				NSRect	newVisibleRect;
				float	xDelta, yDelta;
				
				newLocation = [theEvent locationInWindow];
				xDelta = initialLocation.x - newLocation.x;
				yDelta = initialLocation.y - newLocation.y;
				if ([self isFlipped])
					yDelta = -yDelta;
				
				newVisibleRect = NSOffsetRect (visibleRect, xDelta, yDelta);
				[[self documentView] scrollRectToVisible: newVisibleRect];
			}
				break;
				
			case NSLeftMouseUp:
				keepGoing = NO;
				break;
				
			default:
				/* Ignore any other kind of event. */
				break;
		} // end of switch (event type)
	} // end of mouse-tracking loop
}

@end


/* Following functions are from OmniBase/OBUtilities.h and subject to the following copyright */

// Copyright 1997-2006 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <objc/objc.h>
#import <objc/objc-class.h>
#import <objc/objc-runtime.h>

static void _OBRegisterMethod(IMP methodImp, Class class, const char *methodTypes, SEL selector)
{
    struct objc_method_list *newMethodList;
    
    newMethodList = (struct objc_method_list *) NSZoneMalloc(NSDefaultMallocZone(), sizeof(struct objc_method_list));
    
    newMethodList->method_count = 1;
    newMethodList->method_list[0].method_name = selector;
    newMethodList->method_list[0].method_imp = methodImp;
    newMethodList->method_list[0].method_types = (char *)methodTypes;
    
    class_addMethods(class, newMethodList);
}

IMP OBRegisterInstanceMethodWithSelector(Class aClass, SEL oldSelector, SEL newSelector)
{
    struct objc_method *thisMethod;
    IMP oldImp = NULL;
    
    if ((thisMethod = class_getInstanceMethod(aClass, oldSelector))) {
        oldImp = thisMethod->method_imp;
        _OBRegisterMethod(thisMethod->method_imp, aClass, thisMethod->method_types, newSelector);
    }
    
    return oldImp;
}

IMP OBReplaceMethodImplementation(Class aClass, SEL oldSelector, IMP newImp)
{
    struct objc_method *localMethod, *superMethod;
    IMP oldImp = NULL;
    extern void _objc_flush_caches(Class);
    
    if ((localMethod = class_getInstanceMethod(aClass, oldSelector))) {
        oldImp = localMethod->method_imp;
        superMethod = aClass->super_class ? class_getInstanceMethod(aClass->super_class, oldSelector) : NULL;
        
        if (superMethod == localMethod) {
            // We are inheriting this method from the superclass.  We do *not* want to clobber the superclass's Method structure as that would replace the implementation on a greater scope than the caller wanted.  In this case, install a new method at this class and return the superclass's implementation as the old implementation (which it is).
            _OBRegisterMethod(newImp, aClass, localMethod->method_types, oldSelector);
        } else {
            // Replace the method in place
            localMethod->method_imp = newImp;
        }
        
        // Flush the method cache
        _objc_flush_caches(aClass);
    }
    
    return oldImp;
}

IMP OBReplaceMethodImplementationWithSelector(Class aClass, SEL oldSelector, SEL newSelector)
{
    struct objc_method *newMethod;
    
    newMethod = class_getInstanceMethod(aClass, newSelector);
    
    return OBReplaceMethodImplementation(aClass, oldSelector, newMethod->method_imp);
}
