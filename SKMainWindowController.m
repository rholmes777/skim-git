//
//  SKMainWindowController.m


//  This code is licensed under a BSD license. Please see the file LICENSE for details.
//
//  Created by Michael McCracken on 12/6/06.
//  Copyright 2006 Michael O. McCracken. All rights reserved.
//

#import "SKMainWindowController.h"
#import "SKStringConstants.h"
#import "SKApplication.h"
#import "SKStringConstants.h"
#import "SKSnapshotWindowController.h"
#import "SKNoteWindowController.h"
#import "SKInfoWindowController.h"
#import "SKFullScreenWindow.h"
#import "SKNavigationWindow.h"
#import "SKSideWindow.h"
#import <Quartz/Quartz.h>
#import "PDFPage_SKExtensions.h"
#import "SKDocument.h"
#import "SKThumbnail.h"
#import "SKPDFView.h"
#import "BDSKCollapsibleView.h"
#import "BDSKEdgeView.h"
#import "SKPDFAnnotationNote.h"
#import "SKSplitView.h"
#import "NSString_SKExtensions.h"
#import "SKAnnotationTypeIconTransformer.h"
#import "NSScrollView_SKExtensions.h"
#import <Carbon/Carbon.h>

#define SEGMENTED_CONTROL_HEIGHT    25.0
#define WINDOW_X_DELTA              0.0
#define WINDOW_Y_DELTA              70.0

static NSString *SKMainWindowFrameAutosaveName = @"SKMainWindowFrameAutosaveName";

static NSString *SKDocumentToolbarIdentifier = @"SKDocumentToolbarIdentifier";

static NSString *SKDocumentToolbarPreviousItemIdentifier = @"SKDocumentPreviousToolbarItemIdentifier";
static NSString *SKDocumentToolbarNextItemIdentifier = @"SKDocumentNextToolbarItemIdentifier";
static NSString *SKDocumentToolbarBackForwardItemIdentifier = @"SKDocumentToolbarBackForwardItemIdentifier";
static NSString *SKDocumentToolbarPageNumberItemIdentifier = @"SKDocumentToolbarPageNumberItemIdentifier";
static NSString *SKDocumentToolbarScaleItemIdentifier = @"SKDocumentToolbarScaleItemIdentifier";
static NSString *SKDocumentToolbarZoomInItemIdentifier = @"SKDocumentZoomInToolbarItemIdentifier";
static NSString *SKDocumentToolbarZoomOutItemIdentifier = @"SKDocumentZoomOutToolbarItemIdentifier";
static NSString *SKDocumentToolbarZoomActualItemIdentifier = @"SKDocumentZoomActualToolbarItemIdentifier";
static NSString *SKDocumentToolbarZoomAutoItemIdentifier = @"SKDocumentZoomAutoToolbarItemIdentifier";
static NSString *SKDocumentToolbarRotateRightItemIdentifier = @"SKDocumentRotateRightToolbarItemIdentifier";
static NSString *SKDocumentToolbarRotateLeftItemIdentifier = @"SKDocumentRotateLeftToolbarItemIdentifier";
static NSString *SKDocumentToolbarFullScreenItemIdentifier = @"SKDocumentFullScreenToolbarItemIdentifier";
static NSString *SKDocumentToolbarPresentationItemIdentifier = @"SKDocumentToolbarPresentationItemIdentifier";
static NSString *SKDocumentToolbarNewNoteItemIdentifier = @"SKDocumentToolbarNewNoteItemIdentifier";
static NSString *SKDocumentToolbarToggleDrawerItemIdentifier = @"SKDocumentToolbarToggleDrawerItemIdentifier";
static NSString *SKDocumentToolbarInfoItemIdentifier = @"SKDocumentToolbarInfoItemIdentifier";
static NSString *SKDocumentToolbarToolModeItemIdentifier = @"SKDocumentToolbarToolModeItemIdentifier";
static NSString *SKDocumentToolbarAnnotationModeItemIdentifier = @"SKDocumentToolbarAnnotationModeItemIdentifier";
static NSString *SKDocumentToolbarDisplayBoxItemIdentifier = @"SKDocumentToolbarDisplayBoxItemIdentifier";
static NSString *SKDocumentToolbarContentsPaneItemIdentifier = @"SKDocumentToolbarContentsPaneItemIdentifier";
static NSString *SKDocumentToolbarNotesPaneItemIdentifier = @"SKDocumentToolbarNotesPaneItemIdentifier";
static NSString *SKDocumentToolbarSearchItemIdentifier = @"SKDocumentToolbarSearchItemIdentifier";

#define TOOLBAR_SEARCHFIELD_MIN_SIZE NSMakeSize(110.0, 22.0)
#define TOOLBAR_SEARCHFIELD_MAX_SIZE NSMakeSize(1000.0, 22.0)


@implementation SKMainWindowController

+ (void)initialize {
    [NSValueTransformer setValueTransformer:[[[SKAnnotationTypeIconTransformer alloc] init] autorelease] forName:@"SKAnnotationTypeIconTransformer"];
}

- (id)initWithWindowNibName:(NSString *)windowNibName owner:(id)owner{
    self = [super initWithWindowNibName:windowNibName owner:owner];
    
    if(self){
        [self setShouldCloseDocument:YES];
        isPresentation = NO;
        searchResults = [[NSMutableArray alloc] init];
        thumbnails = [[NSMutableArray alloc] init];
        dirtyThumbnailIndexes = [[NSMutableIndexSet alloc] init];
        snapshots = [[NSMutableArray alloc] init];
        dirtySnapshotIndexes = [[NSMutableIndexSet alloc] init];
        lastViewedPages = [[NSMutableArray alloc] init];
        leftSidePaneState = SKOutlineSidePaneState;
        rightSidePaneState = SKNoteSidePaneState;
    }
    
    return self;
}

- (void)dealloc {
    
	[[NSNotificationCenter defaultCenter] removeObserver: self];
    [self unregisterForChangeNotification];
    
    if (thumbnailTimer) {
        [thumbnailTimer invalidate];
        [thumbnailTimer release];
        thumbnailTimer = nil;
    }
    if (snapshotTimer) {
        [snapshotTimer invalidate];
        [snapshotTimer release];
        snapshotTimer = nil;
    }
    [dirtyThumbnailIndexes release];
    [dirtySnapshotIndexes release];
	[searchResults release];
    [pdfOutline release];
	[thumbnails release];
	[snapshots release];
    [lastViewedPages release];
    [[outlineView enclosingScrollView] release];
    [[findTableView enclosingScrollView] release];
    [[thumbnailTableView enclosingScrollView] release];
    [[noteTableView enclosingScrollView] release];
    [[snapshotTableView enclosingScrollView] release];
	[leftSideWindow release];
	[rightSideWindow release];
	[fullScreenWindow release];
    [mainWindow release];
    
    [super dealloc];
}

- (void)windowDidLoad{
    // this needs to be done before loading the PDFDocument
    [self resetThumbnailSizeIfNeeded];
    [self resetSnapshotSizeIfNeeded];
    
    // this is not called automatically, because the document overrides makeWindowControllers
    [[self document] windowControllerDidLoadNib:self];
    
    // we retain as we might replace it with the full screen window
    mainWindow = [[self window] retain];
    
    [[self window] setFrameUsingName:SKMainWindowFrameAutosaveName];
    static NSPoint nextWindowLocation = {0.0, 0.0};
    [self setShouldCascadeWindows:NO];
    if ([[self window] setFrameAutosaveName:SKMainWindowFrameAutosaveName]) {
        NSRect windowFrame = [[self window] frame];
        nextWindowLocation = NSMakePoint(NSMinX(windowFrame), NSMaxY(windowFrame));
    }
    nextWindowLocation = [[self window] cascadeTopLeftFromPoint:nextWindowLocation];
    
    [[self window] setBackgroundColor:[NSColor colorWithDeviceWhite:0.9 alpha:1.0]];
    
    [[outlineView enclosingScrollView] retain];
    [[findTableView enclosingScrollView] retain];
    [[thumbnailTableView enclosingScrollView] retain];
    [[noteTableView enclosingScrollView] retain];
    [[snapshotTableView enclosingScrollView] retain];
    
    NSRect frame = [leftSideButton frame];
    frame.size.height = SEGMENTED_CONTROL_HEIGHT;
    [leftSideButton setFrame:frame];
    [[leftSideButton cell] setToolTip:NSLocalizedString(@"View Thumbnails", @"Tool tip message") forSegment:SKThumbnailSidePaneState];
    [[leftSideButton cell] setToolTip:NSLocalizedString(@"View Table of Contents", @"Tool tip message") forSegment:SKOutlineSidePaneState];
    
    frame = [rightSideButton frame];
    frame.size.height = SEGMENTED_CONTROL_HEIGHT;
    [rightSideButton setFrame:frame];
    [[rightSideButton cell] setToolTip:NSLocalizedString(@"View Notes", @"Tool tip message") forSegment:SKNoteSidePaneState];
    [[rightSideButton cell] setToolTip:NSLocalizedString(@"View Snapshots", @"Tool tip message") forSegment:SKSnapshotSidePaneState];
    
    [searchBox setCollapseEdges:BDSKMaxXEdgeMask | BDSKMinYEdgeMask];
    [searchBox setMinSize:NSMakeSize(150.0, 42.0)];
    
    [pdfContentBox setEdges:BDSKMinXEdgeMask | BDSKMaxXEdgeMask];
    [leftSideEdgeView setEdges:BDSKMaxXEdgeMask];
    [rightSideEdgeView setEdges:BDSKMinXEdgeMask];
    
    NSSortDescriptor *indexSortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"pageIndex" ascending:YES] autorelease];
    NSSortDescriptor *contentsSortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"contents" ascending:YES] autorelease];
    [noteArrayController setSortDescriptors:[NSArray arrayWithObjects:indexSortDescriptor, contentsSortDescriptor, nil]];
    [snapshotArrayController setSortDescriptors:[NSArray arrayWithObjects:indexSortDescriptor, nil]];
    
    [self setupToolbar];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKOpenFilesMaximizedKey])
        [[self window] setFrame:[[NSScreen mainScreen] visibleFrame] display:NO];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDefaultDocumentAutoScaleKey])
        [pdfView setAutoScales:YES];
    else
        [pdfView setScaleFactor:0.01 * [[NSUserDefaults standardUserDefaults] floatForKey:SKDefaultDocumentScaleKey]];

    if (pdfOutline == nil) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SKOpenContentsPaneOnlyForTOCKey])
            [self toggleLeftSidePane:self];
        else
            [self setLeftSidePaneState:SKThumbnailSidePaneState];
    }
    if (NSWidth([rightSideContentBox frame]) > 0.0)
        [self toggleRightSidePane:self];
    
    [pdfView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:SKBackgroundColorKey]]];
    
    [[self window] makeFirstResponder:[pdfView documentView]];
    
    [self handleChangedHistoryNotification:nil];
    [self handlePageChangedNotification:nil];
    [self handleScaleChangedNotification:nil];
    
    [self registerForNotifications];
    [self registerAsObserver];
}

- (void)registerForNotifications {
    // Application
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillTerminateNotification:) 
                                                 name:SKApplicationWillTerminateNotification object:NSApp];
	// PDFView
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePageChangedNotification:) 
                                                 name:PDFViewPageChangedNotification object:pdfView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleScaleChangedNotification:) 
                                                 name:PDFViewScaleChangedNotification object:pdfView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleChangedHistoryNotification:) 
                                                 name:PDFViewChangedHistoryNotification object:pdfView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidChangeActiveAnnotationNotification:) 
                                                 name:SKPDFViewActiveAnnotationDidChangeNotification object:pdfView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidAddAnnotationNotification:) 
                                                 name:SKPDFViewDidAddAnnotationNotification object:pdfView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidRemoveAnnotationNotification:) 
                                                 name:SKPDFViewDidRemoveAnnotationNotification object:pdfView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidChangeAnnotationNotification:) 
                                                 name:SKPDFViewDidChangeAnnotationNotification object:pdfView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDoubleClickedAnnotationNotification:) 
                                                 name:SKPDFViewAnnotationDoubleClickedNotification object:pdfView];
}

- (void)registerForDocumentNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDocumentBeginWrite:) 
                                                 name:@"PDFDidBeginDocumentWrite" object:[pdfView document]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDocumentEndWrite:) 
                                                 name:@"PDFDidEndDocumentWrite" object:[pdfView document]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDocumentEndPageWrite:) 
                                                 name:@"PDFDidEndPageWrite" object:[pdfView document]];
}

- (void)unregisterForDocumentNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"PDFDidBeginDocumentWrite" object:[pdfView document]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"PDFDidEndDocumentWrite" object:[pdfView document]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"PDFDidEndPageWrite" object:[pdfView document]];
}

- (void)registerAsObserver {
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKey:SKBackgroundColorKey];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKey:SKFullScreenBackgroundColorKey];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKey:SKSearchHighlightColorKey];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKey:SKShouldHighlightSearchResultsKey];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKey:SKThumbnailSizeKey];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKey:SKSnapshotThumbnailSizeKey];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKey:SKSnapshotsOnTopKey];
}

- (void)unregisterForChangeNotification {
    [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKey:SKBackgroundColorKey];
    [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKey:SKFullScreenBackgroundColorKey];
    [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKey:SKSearchHighlightColorKey];
    [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKey:SKShouldHighlightSearchResultsKey];
    [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKey:SKThumbnailSizeKey];
    [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKey:SKSnapshotThumbnailSizeKey];
    [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKey:SKSnapshotsOnTopKey];
}

- (void)setupWindow:(NSDictionary *)setup{
    [[self window] setFrame:NSRectFromString([setup objectForKey:@"windowFrame"]) display:NO];
    NSRect frame = [leftSideContentBox frame];
    frame.size.width = [[setup objectForKey:@"leftSidePaneWidth"] floatValue];
    [leftSideContentBox setFrame:frame];
    frame = [rightSideContentBox frame];
    frame.size.width = [[setup objectForKey:@"rightSidePaneWidth"] floatValue];
    [rightSideContentBox setFrame:frame];
    frame = [pdfContentBox frame];
    frame.size.width = NSWidth([splitView frame]) - NSWidth([leftSideContentBox frame]) - NSWidth([rightSideContentBox frame]) - 2 * [splitView dividerThickness];
    [pdfContentBox setFrame:frame];
    [pdfView setScaleFactor:[[setup objectForKey:@"scaleFactor"] floatValue]];
    [pdfView setAutoScales:[[setup objectForKey:@"autoScales"] boolValue]];
    [pdfView setDisplaysPageBreaks:[[setup objectForKey:@"displaysPageBreaks"] boolValue]];
    [pdfView setDisplaysAsBook:[[setup objectForKey:@"displaysAsBook"] boolValue]];
    [pdfView setDisplayMode:[[setup objectForKey:@"displayMode"] intValue]];
    [pdfView setDisplayBox:[[setup objectForKey:@"displayBox"] intValue]];
    [pdfView goToPage:[[pdfView document] pageAtIndex:[[setup objectForKey:@"pageIndex"] intValue]]];
}

- (NSDictionary *)currentSetup {
    NSMutableDictionary *setup = [NSMutableDictionary dictionary];
    
    [setup setObject:NSStringFromRect([mainWindow frame]) forKey:@"windowFrame"];
    [setup setObject:[NSNumber numberWithFloat:NSWidth([leftSideContentBox frame])] forKey:@"leftSidePaneWidth"];
    [setup setObject:[NSNumber numberWithFloat:NSWidth([rightSideContentBox frame])] forKey:@"rightSidePaneWidth"];
    [setup setObject:[NSNumber numberWithUnsignedInt:[[pdfView document] indexForPage:[pdfView currentPage]]] forKey:@"pageIndex"];
    [setup setObject:[NSNumber numberWithBool:[pdfView displaysPageBreaks]] forKey:@"displaysPageBreaks"];
    [setup setObject:[NSNumber numberWithBool:[pdfView displaysAsBook]] forKey:@"displaysAsBook"];
    [setup setObject:[NSNumber numberWithInt:[pdfView displayBox]] forKey:@"displayBox"];
    if ([self isPresentation]) {
        [setup setObject:[NSNumber numberWithFloat:savedState.scaleFactor] forKey:@"scaleFactor"];
        [setup setObject:[NSNumber numberWithBool:savedState.autoScales] forKey:@"autoScales"];
        [setup setObject:[NSNumber numberWithInt:savedState.displayMode] forKey:@"displayMode"];
    } else {
        [setup setObject:[NSNumber numberWithFloat:[pdfView scaleFactor]] forKey:@"scaleFactor"];
        [setup setObject:[NSNumber numberWithBool:[pdfView autoScales]] forKey:@"autoScales"];
        [setup setObject:[NSNumber numberWithInt:[pdfView displayMode]] forKey:@"displayMode"];
    }
    
    return setup;
}

#pragma mark Accessors

- (PDFDocument *)pdfDocument{
    return [pdfView document];
}

- (void)setPdfDocument:(PDFDocument *)document{
    if ([pdfView document] != document) {
        
        [self unregisterForDocumentNotifications];
        
        [[pdfView document] setDelegate:nil];
        [pdfView setDocument:document];
        [[pdfView document] setDelegate:self];
        
        [self registerForDocumentNotifications];
        
        [pdfOutline release];
        pdfOutline = [[[pdfView document] outlineRoot] retain];
        if (outline && [[pdfView document] isLocked] == NO) {
            [outlineView reloadData];
            [outlineView setAutoresizesOutlineColumn: NO];
            
            if ([outlineView numberOfRows] == 1)
                [outlineView expandItem: [outlineView itemAtRow: 0] expandChildren: NO];
            [self updateOutlineSelection];
        }
        
        [self updateNoteSelection];
        
        [self resetThumbnails];
        [self updateThumbnailSelection];
    }
}

- (void)setAnnotationsFromDictionaries:(NSArray *)noteDicts{
    NSMutableArray *notes = [[self document] mutableArrayValueForKey:@"notes"];
    NSEnumerator *e = [notes objectEnumerator];
    PDFAnnotation *annotation;
    NSDictionary *dict;
    PDFDocument *pdfDoc = [pdfView document];
    
    // remove the current anotations
    [pdfView endAnnotationEdit:self];
    while (annotation = [e nextObject]) {
        [pdfView setNeedsDisplayForAnnotation:annotation];
        [[annotation page] removeAnnotation:annotation];
    }
    [notes removeAllObjects];
    
    // create new annotations from the dictionary and add them to their page and to the document
    e = [noteDicts objectEnumerator];
    while (dict = [e nextObject]) {
        unsigned pageIndex = [[dict objectForKey:@"pageIndex"] unsignedIntValue];
        if (annotation = [[PDFAnnotation alloc] initWithDictionary:dict]) {
            if (pageIndex == NSNotFound)
                pageIndex = 0;
            else if (pageIndex >= [pdfDoc pageCount])
                pageIndex = [pdfDoc pageCount] - 1;
            PDFPage *page = [pdfDoc pageAtIndex:pageIndex];
            [page addAnnotation:annotation];
            [notes addObject:annotation];
            [annotation release];
        }
    }
    [self thumbnailsAtIndexesNeedUpdate:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [pdfDoc pageCount])]];
}

- (PDFView *)pdfView {
    return pdfView;
}

- (unsigned int)pageNumber {
    return [[pdfView document] indexForPage:[pdfView currentPage]] + 1;
}

- (void)setPageNumber:(unsigned int)pageNumber {
    // Check that the page number exists
    unsigned int pageCount = [[pdfView document] pageCount];
    if (pageNumber > pageCount)
        [pdfView goToPage:[[pdfView document] pageAtIndex:pageCount - 1]];
    else if (pageNumber > 0)
        [pdfView goToPage:[[pdfView document] pageAtIndex:pageNumber - 1]];
}

- (BOOL)isFullScreen {
    return [self window] == fullScreenWindow && isPresentation == NO;
}

- (BOOL)isPresentation {
    return isPresentation;
}

- (BOOL)autoScales {
    return [pdfView autoScales];
}

- (SKLeftSidePaneState)leftSidePaneState {
    return leftSidePaneState;
}

- (void)setLeftSidePaneState:(SKLeftSidePaneState)newLeftSidePaneState {
    if (leftSidePaneState != newLeftSidePaneState) {
        leftSidePaneState = newLeftSidePaneState;
        
        if ([findField stringValue] && [[findField stringValue] isEqualToString:@""] == NO) {
            [findField setStringValue:@""];
            [self removeTemporaryAnnotations];
        }
        
        if (leftSidePaneState == SKThumbnailSidePaneState)
            [self displayThumbnailView];
        else if (leftSidePaneState == SKOutlineSidePaneState)
            [self displayOutlineView];
    }
}

- (SKRightSidePaneState)rightSidePaneState {
    return rightSidePaneState;
}

- (void)setRightSidePaneState:(SKRightSidePaneState)newRightSidePaneState {
    if (rightSidePaneState != newRightSidePaneState) {
        rightSidePaneState = newRightSidePaneState;
        
        if (rightSidePaneState == SKNoteSidePaneState)
            [self displayNoteView];
        else if (rightSidePaneState == SKSnapshotSidePaneState)
            [self displaySnapshotView];
    }
}

- (NSArray *)thumbnails {
    return thumbnails;
}

- (void)setThumbnails:(NSArray *)newThumbnails {
    [thumbnails setArray:thumbnails];
}

- (unsigned)countOfThumbnails {
    return [thumbnails count];
}

- (id)objectInThumbnailsAtIndex:(unsigned)theIndex {
    return [thumbnails objectAtIndex:theIndex];
}

- (void)insertObject:(id)obj inThumbnailsAtIndex:(unsigned)theIndex {
    [thumbnails insertObject:obj atIndex:theIndex];
}

- (void)removeObjectFromThumbnailsAtIndex:(unsigned)theIndex {
    [thumbnails removeObjectAtIndex:theIndex];
}

- (NSArray *)snapshots {
    return snapshots;
}

- (void)setSnapshots:(NSArray *)newSnapshots {
    [snapshots setArray:snapshots];
}

- (unsigned)countOfSnapshots {
    return [snapshots count];
}

- (id)objectInSnapshotsAtIndex:(unsigned)theIndex {
    return [snapshots objectAtIndex:theIndex];
}

- (void)insertObject:(id)obj inSnapshotsAtIndex:(unsigned)theIndex {
    [snapshots insertObject:obj atIndex:theIndex];
}

- (void)removeObjectFromSnapshotsAtIndex:(unsigned)theIndex {
    [snapshots removeObjectAtIndex:theIndex];
}

#pragma mark Actions

- (IBAction)pickColor:(id)sender{
    PDFAnnotation *annotation = [pdfView activeAnnotation];
    if ([annotation isNoteAnnotation])
        [[NSColorPanel sharedColorPanel] setColor:[annotation color]];
    [[NSColorPanel sharedColorPanel] makeKeyAndOrderFront:self];
}

- (IBAction)changeColor:(id)sender{
    PDFAnnotation *annotation = [pdfView activeAnnotation];
    if ([annotation isNoteAnnotation]) {
        [annotation setDefaultColor:[sender color]];
        [pdfView setNeedsDisplayForAnnotation:annotation];
    }
}

- (IBAction)createNewNote:(id)sender{
    [pdfView addAnnotation:sender];
}

- (void)selectNotes:(NSArray *)notesToShow{
    // there should only be a single note
    PDFAnnotation *annotation = [notesToShow lastObject];
    [pdfView scrollAnnotationToVisible:annotation];
	[pdfView setActiveAnnotation:annotation];
}

- (IBAction)displaySinglePages:(id)sender {
    PDFDisplayMode displayMode = [pdfView displayMode];
    if (displayMode == kPDFDisplayTwoUp)
        [pdfView setDisplayMode:kPDFDisplaySinglePage];
    else if (displayMode == kPDFDisplayTwoUpContinuous)
        [pdfView setDisplayMode:kPDFDisplaySinglePageContinuous];
}

- (IBAction)displayFacingPages:(id)sender {
    PDFDisplayMode displayMode = [pdfView displayMode];
    if (displayMode == kPDFDisplaySinglePage) 
        [pdfView setDisplayMode:kPDFDisplayTwoUp];
    else if (displayMode == kPDFDisplaySinglePageContinuous)
        [pdfView setDisplayMode:kPDFDisplayTwoUpContinuous];
}

- (IBAction)toggleDisplayContinuous:(id)sender {
    PDFDisplayMode displayMode = [pdfView displayMode];
    if (displayMode == kPDFDisplaySinglePage) 
        displayMode = kPDFDisplaySinglePageContinuous;
    else if (displayMode == kPDFDisplaySinglePageContinuous)
        displayMode = kPDFDisplaySinglePage;
    else if (displayMode == kPDFDisplayTwoUp)
        displayMode = kPDFDisplayTwoUpContinuous;
    else if (displayMode == kPDFDisplayTwoUpContinuous)
        displayMode = kPDFDisplayTwoUp;
    [pdfView setDisplayMode:displayMode];
}

- (IBAction)toggleDisplayAsBook:(id)sender {
    [pdfView setDisplaysAsBook:[pdfView displaysAsBook] == NO];
}

- (IBAction)toggleDisplayPageBreaks:(id)sender {
    [pdfView setDisplaysPageBreaks:[pdfView displaysPageBreaks] == NO];
}

- (IBAction)displayMediaBox:(id)sender {
    if ([pdfView displayBox] == kPDFDisplayBoxCropBox)
        [pdfView setDisplayBox:kPDFDisplayBoxMediaBox];
}

- (IBAction)displayCropBox:(id)sender {
    if ([pdfView displayBox] == kPDFDisplayBoxMediaBox)
        [pdfView setDisplayBox:kPDFDisplayBoxCropBox];
}

- (IBAction)changeDisplayBox:(id)sender {
    PDFDisplayBox displayBox = [sender indexOfSelectedItem] == 0 ? kPDFDisplayBoxMediaBox : kPDFDisplayBoxCropBox;
    [pdfView setDisplayBox:displayBox];
}

- (IBAction)doGoToNextPage:(id)sender {
    [pdfView goToNextPage:sender];
}

- (IBAction)doGoToPreviousPage:(id)sender {
    [pdfView goToPreviousPage:sender];
}

- (void)choosePageSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSOKButton)
        [self setPageNumber:[choosePageField intValue]];
}

- (IBAction)doGoToPage:(id)sender {
    [choosePageField setStringValue:@""];
    
    [NSApp beginSheet: choosePageSheet
       modalForWindow: [self window]
        modalDelegate: self
       didEndSelector: @selector(choosePageSheetDidEnd:returnCode:contextInfo:)
          contextInfo: nil];
}

- (IBAction)dismissChoosePageSheet:(id)sender {
    [NSApp endSheet:choosePageSheet returnCode:[sender tag]];
    [choosePageSheet orderOut:self];
}

- (IBAction)doGoBack:(id)sender {
    [pdfView goBack:sender];
}

- (IBAction)doGoForward:(id)sender {
    [pdfView goForward:sender];
}

- (IBAction)goBackOrForward:(id)sender {
    if ([sender selectedSegment] == 1)
        [pdfView goForward:sender];
    else
        [pdfView goBack:sender];
}

- (IBAction)doZoomIn:(id)sender {
    [pdfView zoomIn:sender];
}

- (IBAction)doZoomOut:(id)sender {
    [pdfView zoomOut:sender];
}

- (IBAction)doZoomToActualSize:(id)sender {
    [pdfView setScaleFactor:1.0];
}

- (IBAction)doZoomToFit:(id)sender {
    [pdfView setAutoScales:YES];
}

- (IBAction)toggleZoomToFit:(id)sender {
    if ([pdfView autoScales])
        [self doZoomToActualSize:sender];
    else
        [self doZoomToFit:sender];
}

- (IBAction)rotateRight:(id)sender {
    [[pdfView currentPage] setRotation:[[pdfView currentPage] rotation] + 90];
    [pdfView layoutDocumentView];
    [self thumbnailAtIndexNeedsUpdate:[[pdfView document] indexForPage:[pdfView currentPage]]];
}

- (IBAction)rotateLeft:(id)sender {
    [[pdfView currentPage] setRotation:[[pdfView currentPage] rotation] - 90];
    [pdfView layoutDocumentView];
    [self thumbnailAtIndexNeedsUpdate:[[pdfView document] indexForPage:[pdfView currentPage]]];
}

- (IBAction)rotateAllRight:(id)sender {
    int i, count = [[pdfView document] pageCount];
    for (i = 0 ; i < count; ++ i ) {
        [[[pdfView document] pageAtIndex:i] setRotation:[[[pdfView document] pageAtIndex:i] rotation] + 90];
    }
    [pdfView layoutDocumentView];
    [self thumbnailsAtIndexesNeedUpdate:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self countOfThumbnails])]];
}

- (IBAction)rotateAllLeft:(id)sender {
    int i, count = [[pdfView document] pageCount];
    for (i = 0 ; i < count; ++ i ) {
        [[[pdfView document] pageAtIndex:i] setRotation:[[[pdfView document] pageAtIndex:i] rotation] - 90];
    }
    [pdfView layoutDocumentView];
    [self thumbnailsAtIndexesNeedUpdate:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self countOfThumbnails])]];
}

- (IBAction)getInfo:(id)sender {
    SKInfoWindowController *infoController = [SKInfoWindowController sharedInstance];
    [infoController fillInfoForDocument:[self document]];
    [infoController showWindow:self];
}

- (IBAction)changeScaleFactor:(id)sender {
    int scale = [sender intValue];

	if (scale >= 10.0 && scale <= 500.0 ) {
		[pdfView setScaleFactor:scale / 100.0f];
		[pdfView setAutoScales:NO];
	}
}

- (IBAction)changeToolMode:(id)sender {
    [pdfView setToolMode:[sender tag]];
}

- (IBAction)changeAnnotationMode:(id)sender {
    [pdfView setAnnotationMode:[sender tag]];
}


- (IBAction)toggleLeftSidePane:(id)sender {
    NSRect sideFrame = [leftSideContentBox frame];
    NSRect pdfFrame = [pdfContentBox frame];
    
    if(NSWidth(sideFrame) > 0.0){
        lastLeftSidePaneWidth = NSWidth(sideFrame); // cache this
        pdfFrame.size.width += lastLeftSidePaneWidth;
        sideFrame.size.width = 0.0;
    } else {
        if(lastLeftSidePaneWidth <= 0.0)
            lastLeftSidePaneWidth = 250.0; // a reasonable value to start
        if (lastLeftSidePaneWidth > 0.5 * NSWidth(pdfFrame))
            lastLeftSidePaneWidth = floorf(0.5 * NSWidth(pdfFrame));
        pdfFrame.size.width -= lastLeftSidePaneWidth;
		sideFrame.size.width = lastLeftSidePaneWidth;
    }
    [leftSideContentBox setFrame:sideFrame];
    [pdfContentBox setFrame:pdfFrame];
    [splitView setNeedsDisplay:YES];
    [splitView adjustSubviews];
}

- (IBAction)toggleRightSidePane:(id)sender {
    NSRect sideFrame = [rightSideContentBox frame];
    NSRect pdfFrame = [pdfContentBox frame];
    
    if(NSWidth(sideFrame) > 1.0){
        lastRightSidePaneWidth = NSWidth(sideFrame); // cache this
        pdfFrame.size.width += lastRightSidePaneWidth;
        sideFrame.size.width = 0.0;
    } else {
        if(lastRightSidePaneWidth <= 0.0)
            lastRightSidePaneWidth = 250.0; // a reasonable value to start
        if (lastRightSidePaneWidth > 0.5 * NSWidth(pdfFrame))
            lastRightSidePaneWidth = floorf(0.5 * NSWidth(pdfFrame));
        pdfFrame.size.width -= lastRightSidePaneWidth;
		sideFrame.size.width = lastRightSidePaneWidth;
    }
    [rightSideContentBox setFrame:sideFrame];
    [pdfContentBox setFrame:pdfFrame];
    [splitView setNeedsDisplay:YES];
    [splitView adjustSubviews];
}

- (IBAction)changeLeftSidePaneState:(id)sender {
    [self setLeftSidePaneState:[sender tag]];
}

- (IBAction)changeRightSidePaneState:(id)sender {
    [self setRightSidePaneState:[sender tag]];
}

- (void)goFullScreen {
    NSScreen *screen = [NSScreen mainScreen]; // @@ or should we use the window's screen?

    // Create the full-screen window if it does not already  exist.
    if (fullScreenWindow == nil) {
        fullScreenWindow = [[SKFullScreenWindow alloc] initWithScreen:screen];
        [fullScreenWindow setDelegate:self];
    } else if (screen != [fullScreenWindow screen]) {
        [fullScreenWindow setFrame:[screen frame] display:NO];
    }
    
    [fullScreenWindow setMainView:pdfView];
    [pdfView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:SKFullScreenBackgroundColorKey]]];
    [pdfView layoutDocumentView];
    [pdfView setNeedsDisplay:YES];
    
    NSEnumerator *wcEnum = [[[self document] windowControllers] objectEnumerator];
    NSWindowController *wc = [wcEnum nextObject];
    
    while (wc = [wcEnum nextObject]) {
        if ([wc isKindOfClass:[SKNoteWindowController class]] || [wc isKindOfClass:[SKSnapshotWindowController class]])
            [[wc window] setLevel:NSFloatingWindowLevel];
    }
    
    [self setWindow:fullScreenWindow];
    [fullScreenWindow makeKeyAndOrderFront:self];
    [mainWindow orderOut:self];
}

- (void)removeFullScreen {
    [pdfView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:SKBackgroundColorKey]]];
    [pdfView layoutDocumentView];
    
    NSEnumerator *wcEnum = [[[self document] windowControllers] objectEnumerator];
    NSWindowController *wc = [wcEnum nextObject];
    BOOL snapshotsOnTop  = [[NSUserDefaults standardUserDefaults] boolForKey:SKSnapshotsOnTopKey];
    
    while (wc = [wcEnum nextObject]) {
        if ([wc isKindOfClass:[SKNoteWindowController class]] || (snapshotsOnTop == NO && [wc isKindOfClass:[SKSnapshotWindowController class]]))
            [[wc window] setLevel:NSNormalWindowLevel];
    }
    
    [self setWindow:mainWindow];
    [mainWindow orderWindow:NSWindowBelow relativeTo:[fullScreenWindow windowNumber]];
    [mainWindow makeKeyWindow];
    [mainWindow display];
    
    NSDictionary *fadeOutDict = [[NSDictionary alloc] initWithObjectsAndKeys:fullScreenWindow, NSViewAnimationTargetKey, NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil];
    NSViewAnimation *animation = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObjects:fadeOutDict, nil]];
    [fadeOutDict release];
    
    [animation setAnimationBlockingMode:NSAnimationBlocking];
    [animation setDuration:0.5];
    [animation startAnimation];
    [animation release];
    [fullScreenWindow orderOut:self];
    [fullScreenWindow setAlphaValue:1.0];
    [mainWindow makeKeyAndOrderFront:self];
}

- (void)showSideWindows {
    if (leftSideWindow == nil) {
        leftSideWindow = [[SKSideWindow alloc] initWithMainController:self edge:NSMinXEdge];
    } else if ([[self window] screen] != [leftSideWindow screen]) {
        [leftSideWindow moveToScreen:[[self window] screen]];
    }
    if (rightSideWindow == nil) {
        rightSideWindow = [[SKSideWindow alloc] initWithMainController:self edge:NSMaxXEdge];
    } else if ([[self window] screen] != [rightSideWindow screen]) {
        [rightSideWindow moveToScreen:[[self window] screen]];
    }
    
    [leftSideBox retain]; // leftSideBox is removed from its old superview in the process
    [leftSideWindow setMainView:leftSideBox];
    [leftSideBox release];
    
    [rightSideBox retain];
    [rightSideWindow setMainView:rightSideBox];
    [rightSideBox release];
    
    [leftSideEdgeView setEdges:BDSKNoEdgeMask];
    [rightSideEdgeView setEdges:BDSKNoEdgeMask];
    
    [leftSideWindow orderFront:self];
    [rightSideWindow orderFront:self];
    
    [pdfView setFrame:NSInsetRect([[pdfView superview] bounds], 3.0, 0.0)];
    [[pdfView superview] setNeedsDisplay:YES];
}

- (void)hideSideWindows {
    [leftSideWindow orderOut:self];
    [rightSideWindow orderOut:self];
    
    [leftSideBox retain]; // leftSideBox is removed from its old superview in the process
    [leftSideBox setFrame:[leftSideContentBox bounds]];
    [leftSideContentBox addSubview:leftSideBox];
    [leftSideBox release];
    
    [rightSideBox retain]; // rightSideBox is removed from its old superview in the process
    [rightSideBox setFrame:[rightSideContentBox bounds]];
    [rightSideContentBox addSubview:rightSideBox];
    [rightSideBox release];
    
    [leftSideEdgeView setEdges:BDSKMaxXEdgeMask];
    [rightSideEdgeView setEdges:BDSKMinXEdgeMask];
    
    [pdfView setFrame:[[pdfView superview] bounds]];
}

- (void)enterPresentationMode {
    NSScrollView *scrollView = [[pdfView documentView] enclosingScrollView];
	// Set up presentation mode
	savedState.displayMode = [pdfView displayMode];
	[pdfView setDisplayMode:kPDFDisplaySinglePage];
	savedState.autoScales = [pdfView autoScales];
	savedState.scaleFactor = [pdfView scaleFactor];
	[pdfView setAutoScales:YES];
	savedState.hasHorizontalScroller = [scrollView hasHorizontalScroller];
	[scrollView setNeverHasHorizontalScroller:YES];
	savedState.hasVerticalScroller = [scrollView hasVerticalScroller];
	[scrollView setNeverHasVerticalScroller:YES];
	savedState.autoHidesScrollers = [scrollView autohidesScrollers];
	[scrollView setAutohidesScrollers:YES];
    
    // Get the screen information.
    NSScreen *screen = [NSScreen mainScreen]; // @@ or should we use the window's screen?
    NSNumber *screenID = [[screen deviceDescription] objectForKey:@"NSScreenNumber"];
    
    // Capture the screen.
    CGDisplayCapture((CGDirectDisplayID)[screenID longValue]);
    
    isPresentation = YES;
}

- (void)exitPresentationMode {
    NSScrollView *scrollView = [[pdfView documentView] enclosingScrollView];
    [pdfView setDisplayMode:savedState.displayMode];
    if (savedState.autoScales) {
        [pdfView setAutoScales:YES];
    } else {
        [pdfView setAutoScales:NO];
        [pdfView setScaleFactor:savedState.scaleFactor];
    }		
    [scrollView setNeverHasHorizontalScroller:NO];		
    [scrollView setHasHorizontalScroller:savedState.hasHorizontalScroller];		
    [scrollView setNeverHasVerticalScroller:NO];		
    [scrollView setHasVerticalScroller:savedState.hasVerticalScroller];
    [scrollView setAutohidesScrollers:savedState.autoHidesScrollers];		
    
    // Get the screen information.
    NSScreen *screen = [fullScreenWindow screen];
    NSNumber *screenID = [[screen deviceDescription] objectForKey:@"NSScreenNumber"];
    CGDisplayRelease((CGDirectDisplayID)[screenID longValue]);
    
    isPresentation = NO;
}

- (IBAction)enterFullScreen:(id)sender {
    if ([self isFullScreen])
        return;
    
    SetSystemUIMode(kUIModeAllHidden, kUIOptionAutoShowMenuBar);
    
    if ([self isPresentation])
        [self exitPresentationMode];
    else
        [self goFullScreen];
    
    [fullScreenWindow setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:SKFullScreenBackgroundColorKey]]];
    [fullScreenWindow setLevel:NSNormalWindowLevel];
    [pdfView setHasNavigation:YES autohidesCursor:NO];
    [self showSideWindows];
}

- (IBAction)enterPresentation:(id)sender {
    if ([self isPresentation])
        return;
    
    BOOL wasFullScreen = [self isFullScreen];
    
    [self enterPresentationMode];
    
    if (wasFullScreen) {
        [self hideSideWindows];
        SetSystemUIMode(kUIModeNormal, 0);
    } else
        [self goFullScreen];
    
    [fullScreenWindow setBackgroundColor:[NSColor blackColor]];
    [fullScreenWindow setLevel:CGShieldingWindowLevel()];
    [pdfView setHasNavigation:YES autohidesCursor:YES];
}

- (IBAction)exitFullScreen:(id)sender {
    if ([self isFullScreen] == NO && [self isPresentation] == NO)
        return;

    if ([self isFullScreen])
        [self hideSideWindows];
    
    [pdfView setHasNavigation:NO autohidesCursor:NO];
    [pdfView setFrame:[[pdfContentBox contentView] bounds]];
    [pdfContentBox addSubview:pdfView]; // this should be done before exitPresentationMode to get a smooth transition
    
    if ([self isPresentation])
        [self exitPresentationMode];
    else
        SetSystemUIMode(kUIModeNormal, 0);
    
    [self removeFullScreen];
}

- (IBAction)toggleFullScreen:(id)sender {
    if ([self isFullScreen])
        [self exitFullScreen:sender];
    else
        [self enterFullScreen:sender];
}

- (IBAction)togglePresentation:(id)sender {
    if ([self isPresentation])
        [self exitFullScreen:sender];
    else
        [self enterPresentation:sender];
}

- (IBAction)printDocument:(id)sender{
    [pdfView printWithInfo:[[self document] printInfo] autoRotate:NO];
}

#pragma mark Swapping tables

- (void)replaceTable:(NSTableView *)oldTableView withTable:(NSTableView *)newTableView animate:(BOOL)animate {
    if ([newTableView window] == nil) {
        NSView *newTable = [newTableView enclosingScrollView];
        NSView *oldTable = [oldTableView enclosingScrollView];
        NSRect frame = [oldTable frame];
        
        [newTable setFrame:frame];
        [newTable setHidden:animate];
        [[oldTable superview] addSubview:newTable];
        
        if (animate) {
            NSViewAnimation *animation;
            NSDictionary *fadeOutDict = [[NSDictionary alloc] initWithObjectsAndKeys:oldTable, NSViewAnimationTargetKey, NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil];
            NSDictionary *fadeInDict = [[NSDictionary alloc] initWithObjectsAndKeys:newTable, NSViewAnimationTargetKey, NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil];
            
            animation = [[[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObjects:fadeOutDict, fadeInDict, nil]] autorelease];
            [fadeOutDict release];
            [fadeInDict release];
            
            [animation setAnimationBlockingMode:NSAnimationBlocking];
            [animation setDuration:0.75];
            [animation setAnimationCurve:NSAnimationEaseIn];
            [animation startAnimation];
        }
        
        [oldTable removeFromSuperview];
        [oldTable setHidden:NO];
    }
}

- (void)displayOutlineView {
    [self replaceTable:currentTableView withTable:outlineView animate:NO];
    currentTableView = outlineView;
    [self updateOutlineSelection];
}

- (void)fadeInOutlineView {
    [self replaceTable:currentTableView withTable:outlineView animate:YES];
    currentTableView = outlineView;
    [self updateOutlineSelection];
}

- (void)displayThumbnailView {
    [self replaceTable:currentTableView withTable:thumbnailTableView animate:NO];
    currentTableView = thumbnailTableView;
    [self updateThumbnailSelection];
    [self updateThumbnailsIfNeeded];
}

- (void)fadeInThumbnailView {
    [self replaceTable:currentTableView withTable:thumbnailTableView animate:YES];
    currentTableView = thumbnailTableView;
    [self updateThumbnailSelection];
    [self updateThumbnailsIfNeeded];
}

- (void)displaySearchView {
    [self replaceTable:currentTableView withTable:findTableView animate:NO];
    currentTableView = findTableView;
}

- (void)fadeInSearchView {
    [self replaceTable:currentTableView withTable:findTableView animate:YES];
    currentTableView = findTableView;
}

- (void)displayNoteView {
    [self replaceTable:snapshotTableView withTable:noteTableView animate:NO];
}

- (void)fadeInNoteView {
    [self replaceTable:snapshotTableView withTable:noteTableView animate:YES];
}

- (void)displaySnapshotView {
    [self replaceTable:noteTableView withTable:snapshotTableView animate:NO];
}

- (void)fadeInSnapshotView {
    [self replaceTable:noteTableView withTable:snapshotTableView animate:YES];
}

#pragma mark Searching

- (void)documentDidBeginDocumentFind:(NSNotification *)note {
    if (findPanelFind == NO) {
        [findArrayController removeObjects:searchResults];
        [spinner startAnimation:nil];
    }
}

- (void)documentDidEndDocumentFind:(NSNotification *)note {
    if (findPanelFind == NO)
        [spinner stopAnimation:nil];
}

- (void)documentDidEndPageFind:(NSNotification *)note {
    if (findPanelFind == NO) {
        double pageIndex = [[[note userInfo] objectForKey:@"PDFDocumentPageIndex"] doubleValue];
        [spinner setDoubleValue: pageIndex / [[pdfView document] pageCount]];
    }
}

- (void)didMatchString:(PDFSelection *)instance {
    if (findPanelFind == NO)
        [findArrayController addObject:instance];
}

- (void)addAnnotationsForSelection:(PDFSelection *)sel {
    PDFDocument *doc = [pdfView document];
    NSArray *pages = [sel pages];
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    int i, iMax = [pages count];
    NSColor *color = nil;
    NSData *colorData = [[NSUserDefaults standardUserDefaults] dataForKey:SKSearchHighlightColorKey];
    
    if (colorData != nil)
        color = [NSUnarchiver unarchiveObjectWithData:colorData];
    if (color == nil)
        color = [NSColor redColor];
    
    for (i = 0; i < iMax; i++) {
        PDFPage *page = [pages objectAtIndex:i];
        NSRect bounds = NSInsetRect([sel boundsForPage:page], -3.0, -3.0);
        SKPDFAnnotationTemporary *circle = [[SKPDFAnnotationTemporary alloc] initWithBounds:bounds];
        [circle setColor:color];
        [page addAnnotation:circle];
        [pdfView setNeedsDisplayForAnnotation:circle];
        [indexes addIndex:[doc indexForPage:page]];
        [circle release];
    }
    
    [self thumbnailsAtIndexesNeedUpdate:indexes];
}

- (void)removeTemporaryAnnotations {
    PDFDocument *doc = [pdfView document];
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    unsigned i, iMax = [doc pageCount];
    for (i = 0; i < iMax; i++) {
        PDFPage *page = [doc pageAtIndex:i];
        NSArray *annotations = [[page annotations] copy];
        unsigned j, jMax = [annotations count];
        PDFAnnotation *annote;
        for (j = 0; j < jMax; j++) {
            annote = [annotations objectAtIndex:j];
            if ([annote isTemporaryAnnotation]) {
                [page removeAnnotation:annote];
                [pdfView setNeedsDisplayForAnnotation:annote];
                [indexes addIndex:[doc indexForPage:page]];
            }
        }
        [annotations release];
    }
    [self thumbnailsAtIndexesNeedUpdate:indexes];
}

- (IBAction)search:(id)sender {
    if ([[sender stringValue] isEqualToString:@""]) {
        // get rid of temporary annotations
        [self removeTemporaryAnnotations];
        if (leftSidePaneState == SKThumbnailSidePaneState)
            [self fadeInThumbnailView];
        else 
            [self fadeInOutlineView];
    } else {
        [self fadeInSearchView];
    }
    [[pdfView document] findString:[sender stringValue] withOptions:NSCaseInsensitiveSearch];
}

- (void)findString:(NSString *)string options:(int)options{
	findPanelFind = YES;
    PDFSelection *selection = [[pdfView document] findString:string fromSelection:[pdfView currentSelection] withOptions:options];
	findPanelFind = NO;
    if (selection) {
        [findTableView deselectAll:self];
		[pdfView setCurrentSelection:selection];
		[pdfView scrollSelectionToVisible:self];
	} else {
		NSBeep();
	}
}

#pragma mark NSTableView delegate protocol

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    if ([[aNotification object] isEqual:findTableView]) {
        
        BOOL highlight = [[NSUserDefaults standardUserDefaults] boolForKey:SKShouldHighlightSearchResultsKey];
        
        // clear the selection
        [pdfView setCurrentSelection:nil];
        [self removeTemporaryAnnotations];
        
        // union all selected objects
        NSEnumerator *selE = [[findArrayController selectedObjects] objectEnumerator];
        PDFSelection *sel;
        
        // arm:  PDFSelection is mutable, and using -addSelection on an object from selectedObjects will actually mutate the object in searchResults, which does bad things.  MagicHat indicates that PDFSelection implements copyWithZone: even though it doesn't conform to <NSCopying>, so we'll use that since -init doesn't work (-initWithDocument: does, but it's not listed in the header either).  I filed rdar://problem/4888251 and also noticed that PDFKitViewer sample code uses -[PDFSelection copy].
        PDFSelection *currentSel = [[[selE nextObject] copy] autorelease];
        
        // add an annotation so it's easier to see the search result
        if (highlight)
            [self addAnnotationsForSelection:currentSel];
        
        while (sel = [selE nextObject]) {
            [currentSel addSelection:sel];
            if (highlight)
                [self addAnnotationsForSelection:sel];
        }
        
        [pdfView setCurrentSelection:currentSel];
        [pdfView scrollSelectionToVisible:self];
    } else if ([[aNotification object] isEqual:thumbnailTableView]) {
        if (updatingThumbnailSelection == NO) {
            int row = [thumbnailTableView selectedRow];
            if (row != -1)
                [pdfView goToPage:[[pdfView document] pageAtIndex:row]];
        }
    } else if ([[aNotification object] isEqual:noteTableView]) {
        // Disable this for now. Selection change does not always come from a selection by the user, e.g. also after an annotation delete 
        return;
        if (updatingNoteSelection == NO) {
            NSArray *selectedNotes = [noteArrayController selectedObjects];
            if ([selectedNotes count])
                [pdfView scrollAnnotationToVisible:[selectedNotes objectAtIndex:0]];
        }
    } else if ([[aNotification object] isEqual:snapshotTableView]) {
        if (updatingThumbnailSelection == NO) {
            int row = [snapshotTableView selectedRow];
            if (row != -1) {
                SKSnapshotWindowController *controller = [[snapshotArrayController arrangedObjects] objectAtIndex:row];
                if ([[controller window] isVisible])
                    [[controller window] orderFront:self];
            }
        }
    }
}

// AppKit bug: need a dummy NSTableDataSource implementation, otherwise some NSTableView delegate methods are ignored
- (int)numberOfRowsInTableView:(NSTableView *)tv { return 0; }

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row { return nil; }

- (NSString *)tableView:(NSTableView *)tv toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(int)row mouseLocation:(NSPoint)mouseLocation{
    if ([tv isEqual:noteTableView])
        return [[[noteArrayController arrangedObjects] objectAtIndex:row] contents];
    return nil;
}

- (float)tableView:(NSTableView *)tableView heightOfRow:(int)row {
    if (tableView == thumbnailTableView) {
        NSSize thumbSize = [[[[thumbnailArrayController arrangedObjects] objectAtIndex:row] image] size];
        NSSize cellSize = NSMakeSize([[[tableView tableColumns] objectAtIndex:0] width], 
                                     MIN(thumbSize.height, roundf([[NSUserDefaults standardUserDefaults] floatForKey:SKThumbnailSizeKey])));
        if (thumbSize.height < 1.0)
            return 1.0;
        else if (thumbSize.width / thumbSize.height < cellSize.width / cellSize.height)
            return cellSize.height;
        else
            return MAX(1.0, MIN(cellSize.width, thumbSize.width) * thumbSize.height / thumbSize.width);
    } else if (tableView == snapshotTableView) {
        NSSize thumbSize = [[[[snapshotArrayController arrangedObjects] objectAtIndex:row] thumbnail] size];
        NSSize cellSize = NSMakeSize([[[tableView tableColumns] objectAtIndex:0] width], 
                                     MIN(thumbSize.height, roundf([[NSUserDefaults standardUserDefaults] floatForKey:SKSnapshotThumbnailSizeKey])));
        if (thumbSize.height < 1.0)
            return 1.0;
        else if (thumbSize.width / thumbSize.height < cellSize.width / cellSize.height)
            return cellSize.height;
        else
            return MAX(1.0, MIN(cellSize.width, thumbSize.width) * thumbSize.height / thumbSize.width);
    }
    return 17.0;
}

- (void)tableView:(NSTableView *)tv deleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
    if ([tv isEqual:noteTableView]) {
        NSArray *notesToRemove = [[noteArrayController arrangedObjects] objectsAtIndexes:rowIndexes];
        NSEnumerator *noteEnum = [notesToRemove objectEnumerator];
        PDFAnnotation *annotation;
        
        while (annotation = [noteEnum nextObject])
            [pdfView removeAnnotation:annotation];
    } else if ([tv isEqual:snapshotTableView]) {
        NSArray *controllers = [[snapshotArrayController arrangedObjects] objectsAtIndexes:rowIndexes];
        [[controllers valueForKey:@"window"] makeObjectsPerformSelector:@selector(orderOut:) withObject:self];
        [[self mutableArrayValueForKey:@"snapshots"] removeObjectsInArray:controllers];
    }
}

- (NSArray *)tableViewHighlightedRows:(NSTableView *)tableView {
    return lastViewedPages;
}

#pragma mark Sub- and note- windows

- (void)showSnapshotAtPageNumber:(int)pageNum forRect:(NSRect)rect{
    
    SKSnapshotWindowController *swc = [[SKSnapshotWindowController alloc] init];
    BOOL snapshotsOnTop = [[NSUserDefaults standardUserDefaults] boolForKey:SKSnapshotsOnTopKey];
    
    [swc setDelegate:self];
    
    PDFDocument *doc = [pdfView document];
    [swc setPdfDocument:doc
            scaleFactor:[pdfView scaleFactor]
         goToPageNumber:pageNum
                   rect:rect];
    
    if ([self isFullScreen] || snapshotsOnTop)
        [[swc window] setLevel:NSFloatingWindowLevel];
    [[swc window] setHidesOnDeactivate:snapshotsOnTop];
    
    [[self document] addWindowController:swc];
    [swc release];
    [swc showWindow:self];
}

- (void)showSnapshots:(NSArray *)snapshotToShow {
    // there should only be a single note
    SKSnapshotWindowController *controller = [snapshotToShow lastObject];
    
    if ([[controller window] isVisible])
        [[controller window] orderFront:self];
    else
        [controller deminiaturize];
}

- (void)snapshotControllerDidFinishSetup:(SKSnapshotWindowController *)controller {
    float shadowBlurRadius = roundf(snapshotCacheSize / 32.0);
    float shadowOffset = - ceilf(shadowBlurRadius * 0.75);
    NSImage *image = [controller thumbnailWithSize:snapshotCacheSize shadowBlurRadius:shadowBlurRadius shadowOffset:NSMakeSize(0.0, shadowOffset)];
    
    [controller setThumbnail:image];
    [[self mutableArrayValueForKey:@"snapshots"] addObject:controller];
}

- (void)snapshotControllerWindowWillClose:(SKSnapshotWindowController *)controller {
    [[self mutableArrayValueForKey:@"snapshots"] removeObject:controller];
}

- (void)snapshotControllerViewDidChange:(SKSnapshotWindowController *)controller {
    int index = [snapshots indexOfObject:controller];
    [self snapshotAtIndexNeedsUpdate:index];
}

- (NSRect)snapshotControllerTargetRectForMiniaturize:(SKSnapshotWindowController *)controller {
    if ([self isPresentation] == NO) {
        if ([self isFullScreen] == NO && NSWidth([rightSideContentBox frame]) <= 0.0)
            [self toggleRightSidePane:self];
        [self setRightSidePaneState:SKSnapshotSidePaneState];
    }
    
    int row = [[snapshotArrayController arrangedObjects] indexOfObject:controller];
    
    [snapshotTableView scrollRowToVisible:row];
    
    NSRect rect = [snapshotTableView frameOfCellAtColumn:0 row:row];
    
    rect = [snapshotTableView convertRect:rect toView:nil];
    rect.origin = [[snapshotTableView window] convertBaseToScreen:rect.origin];
    
    return rect;
}

- (NSRect)snapshotControllerSourceRectForDeminiaturize:(SKSnapshotWindowController *)controller {
    [[self document] addWindowController:controller];
    
    int row = [[snapshotArrayController arrangedObjects] indexOfObject:controller];
    NSRect rect = [snapshotTableView frameOfCellAtColumn:0 row:row];
        
    rect = [snapshotTableView convertRect:rect toView:nil];
    rect.origin = [[snapshotTableView window] convertBaseToScreen:rect.origin];
    
    return rect;
}

- (void)showNote:(PDFAnnotation *)annotation {
    NSWindowController *wc = nil;
    NSEnumerator *wcEnum = [[[self document] windowControllers] objectEnumerator];
    
    while (wc = [wcEnum nextObject]) {
        if ([wc isKindOfClass:[SKNoteWindowController class]] && [(SKNoteWindowController *)wc note] == annotation)
            break;
    }
    if (wc == nil) {
        wc = [[SKNoteWindowController alloc] initWithNote:annotation];
        [[self document] addWindowController:wc];
        [wc release];
    }
    [wc showWindow:self];
}

#pragma mark Notification handlers

- (void)handleChangedHistoryNotification:(NSNotification *)notification {
    [backForwardButton setEnabled:[pdfView canGoBack] forSegment:0];
    [backForwardButton setEnabled:[pdfView canGoForward] forSegment:1];
}

- (void)handlePageChangedNotification:(NSNotification *)notification {
    [lastViewedPages insertObject:[NSNumber numberWithInt:[[pdfView document] indexForPage:[pdfView currentPage]]] atIndex:0];
    if ([lastViewedPages count] > 4)
        [lastViewedPages removeLastObject];
    [thumbnailTableView setNeedsDisplay:YES];
    [outlineView setNeedsDisplay:YES];
    
    [self willChangeValueForKey:@"pageNumber"];
    [self didChangeValueForKey:@"pageNumber"];
    
    [self updateOutlineSelection];
    [self updateNoteSelection];
    [self updateThumbnailSelection];
}

- (void)handleScaleChangedNotification:(NSNotification *)notification {
    [scaleField setFloatValue:[pdfView scaleFactor] * 100.0];
}

- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification {
    if ([self isFullScreen] || [self isPresentation])
        [self exitFullScreen:self];
}

- (void)handleDidChangeActiveAnnotationNotification:(NSNotification *)notification {
    PDFAnnotation *annotation = [pdfView activeAnnotation];
    updatingNoteSelection = YES;
    [noteArrayController setSelectedObjects:[NSArray arrayWithObjects:[annotation isNoteAnnotation] ? annotation : nil, nil]];
    updatingNoteSelection = NO;
    if ([annotation isNoteAnnotation])
        [[NSColorPanel sharedColorPanel] setColor:[annotation color]];
}

- (void)handleDidAddAnnotationNotification:(NSNotification *)notification {
    PDFAnnotation *annotation = [[notification userInfo] objectForKey:@"annotation"];
    PDFPage *page = [[notification userInfo] objectForKey:@"page"];;
    if (annotation) {
        updatingNoteSelection = YES;
        [[(SKDocument *)[self document] mutableArrayValueForKey:@"notes"] addObject:annotation];
        updatingNoteSelection = NO;
        if (page)
            [self thumbnailAtIndexNeedsUpdate:[[pdfView document] indexForPage:page]];
    }
    [[self document] updateChangeCount:NSChangeDone];
}

- (void)handleDidRemoveAnnotationNotification:(NSNotification *)notification {
    PDFAnnotation *annotation = [[notification userInfo] objectForKey:@"annotation"];
    PDFPage *page = [[notification userInfo] objectForKey:@"page"];;
    if (annotation) {
        NSWindowController *wc = nil;
        NSEnumerator *wcEnum = [[[self document] windowControllers] objectEnumerator];
        
        while (wc = [wcEnum nextObject]) {
            if ([wc isKindOfClass:[SKNoteWindowController class]] && [(SKNoteWindowController *)wc note] == annotation) {
                [wc close];
                break;
            }
        }
        [[[self document] mutableArrayValueForKey:@"notes"] removeObject:annotation];
        if (page)
            [self thumbnailAtIndexNeedsUpdate:[[pdfView document] indexForPage:page]];
    }
    [[self document] updateChangeCount:NSChangeDone];
}

- (void)handleDidChangeAnnotationNotification:(NSNotification *)notification {
    PDFAnnotation *annotation = [[notification userInfo] objectForKey:@"annotation"];
    [[self document] updateChangeCount:NSChangeDone];
    [self thumbnailAtIndexNeedsUpdate:[annotation pageIndex]];
}

- (void)handleDoubleClickedAnnotationNotification:(NSNotification *)notification {
    PDFAnnotation *annotation = [[notification userInfo] objectForKey:@"annotation"];
    
    [self showNote:annotation];
}

- (void)saveProgressSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	[saveProgressSheet close];
}

- (void)handleDocumentBeginWrite:(NSNotification *)notification {
    if (saveProgressSheet == nil) {
        if (NO == [NSBundle loadNibNamed:@"SaveProgressSheet" owner:self])  {
            NSLog(@"Failed to load SaveProgressSheet.nib");
            return;
        }
    }
    
	// Establish maximum and current value for progress bar.
	[saveProgressBar setMaxValue: (double)[[pdfView document] pageCount]];
	[saveProgressBar setDoubleValue: 0.0];
	
	// Bring up the save panel as a sheet.
	[NSApp beginSheet:saveProgressSheet
       modalForWindow:[self window]
        modalDelegate:self 
       didEndSelector:@selector(saveProgressSheetDidEnd:returnCode:contextInfo:)
          contextInfo:NULL];
}

- (void)handleDocumentEndWrite:(NSNotification *)notification {
	[NSApp endSheet:saveProgressSheet];
}

- (void)handleDocumentEndPageWrite:(NSNotification *)notification {
	[saveProgressBar setDoubleValue: [[[notification userInfo] objectForKey:@"PDFDocumentPageIndex"] floatValue]];
	[saveProgressBar displayIfNeeded];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == [NSUserDefaultsController sharedUserDefaultsController]) {
        if (NO == [keyPath hasPrefix:@"values."])
            return;
        NSString *key = [keyPath substringFromIndex:7];
        if ([key isEqualToString:SKBackgroundColorKey]) {
            if ([self isFullScreen] == NO && [self isPresentation] == NO)
                [pdfView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:SKBackgroundColorKey]]];
        } else if ([key isEqualToString:SKFullScreenBackgroundColorKey]) {
            if ([self isFullScreen]) {
                NSColor *color = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:SKFullScreenBackgroundColorKey]];
                if (color) {
                    [pdfView setBackgroundColor:color];
                    [fullScreenWindow setBackgroundColor:color];
                    [[fullScreenWindow contentView] setNeedsDisplay:YES];
                }
            }
        } else if ([key isEqualToString:SKSearchHighlightColorKey]) {
            if ([[NSUserDefaults standardUserDefaults] boolForKey:SKShouldHighlightSearchResultsKey] && 
                [[findField stringValue] length] && [findTableView numberOfSelectedRows]) {
                // clear the selection
                [self removeTemporaryAnnotations];
                
                NSEnumerator *selE = [[findArrayController selectedObjects] objectEnumerator];
                PDFSelection *sel;
                
                while (sel = [selE nextObject])
                    [self addAnnotationsForSelection:sel];
            }
        } else if ([key isEqualToString:SKShouldHighlightSearchResultsKey]) {
            if ([[findField stringValue] length] && [findTableView numberOfSelectedRows]) {
                // clear the selection
                [self removeTemporaryAnnotations];
                
                if ([[NSUserDefaults standardUserDefaults] boolForKey:SKShouldHighlightSearchResultsKey]) {
                    NSEnumerator *selE = [[findArrayController selectedObjects] objectEnumerator];
                    PDFSelection *sel;
                    
                    while (sel = [selE nextObject])
                        [self addAnnotationsForSelection:sel];
                }
            }
        } else if ([key isEqualToString:SKThumbnailSizeKey]) {
            [self resetThumbnailSizeIfNeeded];
            [thumbnailTableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self countOfThumbnails])]];
        } else if ([key isEqualToString:SKSnapshotThumbnailSizeKey]) {
            [self resetSnapshotSizeIfNeeded];
            [snapshotTableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self countOfSnapshots])]];
        } else if ([key isEqualToString:SKSnapshotsOnTopKey]) {
            NSEnumerator *wcEnum = [snapshots objectEnumerator];
            NSWindowController *wc = [wcEnum nextObject];
            BOOL snapshotsOnTop  = [[NSUserDefaults standardUserDefaults] boolForKey:SKSnapshotsOnTopKey];
            int level = snapshotsOnTop || [self isFullScreen] ? NSFloatingWindowLevel : NSNormalWindowLevel;
            
            while (wc = [wcEnum nextObject]) {
                [[wc window] setLevel:level];
                [[wc window] setHidesOnDeactivate:snapshotsOnTop];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark NSOutlineView methods

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item{
	if (item == nil){
		if ((pdfOutline) && ([[pdfView document] isLocked] == NO)){
			return [pdfOutline numberOfChildren];
		}else{
			return 0;
        }
	}else{
		return [(PDFOutline *)item numberOfChildren];
    }
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item{
	if (item == nil){
		if ((pdfOutline) && ([[pdfView document] isLocked] == NO)){
            
			return [[pdfOutline childAtIndex: index] retain];
            
        }else{
			return nil;
        }
	}else{
		return [[(PDFOutline *)item childAtIndex: index] retain];
    }
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item{
	if (item == nil){
		if ((pdfOutline) && ([[pdfView document] isLocked] == NO)){
			return ([pdfOutline numberOfChildren] > 0);
		}else{
			return NO;
        }
	}else{
		return ([(PDFOutline *)item numberOfChildren] > 0);
    }
}


- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item{
    NSString *tcID = [tableColumn identifier];
    if([tcID isEqualToString:@"label"]){
        return [(PDFOutline *)item label];
    }else if([tcID isEqualToString:@"icon"]){
        return [[[(PDFOutline *)item destination] page] label];
    }else{
        [NSException raise:@"Unexpected tablecolumn identifier" format:@" - %@ ", tcID];
        return nil;
    }
}


- (void)outlineViewSelectionDidChange:(NSNotification *)notification{
	// Get the destination associated with the search result list. Tell the PDFView to go there.
	if (([notification object] == outlineView) && (updatingOutlineSelection == NO)){
		[pdfView goToDestination: [[outlineView itemAtRow: [outlineView selectedRow]] destination]];
    }
}


- (void)outlineViewItemDidExpand:(NSNotification *)notification{
	[self updateOutlineSelection];
}


- (void)outlineViewItemDidCollapse:(NSNotification *)notification{
	[self updateOutlineSelection];
}

- (int)outlineRowForPageIndex:(unsigned int)pageIndex {
	int i, numRows = [outlineView numberOfRows];
	for (i = 0; i < numRows; i++) {
		// Get the destination of the given row....
		PDFOutline *outlineItem = (PDFOutline *)[outlineView itemAtRow: i];
		
		if ([[pdfView document] indexForPage: [[outlineItem destination] page]] == pageIndex) {
            break;
        } else if ([[pdfView document] indexForPage: [[outlineItem destination] page]] > pageIndex) {
			if (i > 0) --i;
            break;	
		}
	}
    return i == numRows ? -1 : i;
}

- (void)updateOutlineSelection{

	// Skip out if this PDF has no outline.
	if (pdfOutline == nil)
		return;
	
	// Get index of current page.
	unsigned int pageIndex = [[pdfView document] indexForPage: [pdfView currentPage]];
	
	// Test that the current selection is still valid.
	PDFOutline *outlineItem = (PDFOutline *)[outlineView itemAtRow: [outlineView selectedRow]];
	if ([[pdfView document] indexForPage: [[outlineItem destination] page]] == pageIndex)
		return;
	
    int row = [self outlineRowForPageIndex:pageIndex];
    
    if (row != -1) {
        updatingOutlineSelection = YES;
        [outlineView selectRow:row byExtendingSelection: NO];
        updatingOutlineSelection = NO;
    }
}

- (NSArray *)outlineViewHighlightedRows:(NSOutlineView *)anOutlineView {
    NSMutableArray *array = [NSMutableArray array];
    NSEnumerator *rowEnum = [lastViewedPages objectEnumerator];
    NSNumber *rowNumber;
    
    while (rowNumber = [rowEnum nextObject]) {
        int row = [self outlineRowForPageIndex:[rowNumber intValue]];
        if (row != -1)
            [array addObject:[NSNumber numberWithInt:row]];
    }
    
    return array;
}

#pragma mark Thumbnails

- (void)updateThumbnailSelection {
	// Get index of current page.
	unsigned pageIndex = [[pdfView document] indexForPage: [pdfView currentPage]];
    updatingThumbnailSelection = YES;
    [thumbnailTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:pageIndex] byExtendingSelection:NO];
    updatingThumbnailSelection = NO;
}

- (void)resetThumbnails {
    if (thumbnailTimer) {
        [thumbnailTimer invalidate];
        [thumbnailTimer release];
        thumbnailTimer = nil;
    }
    
    PDFDocument *pdfDoc = [pdfView document];
    unsigned i, count = [pdfDoc pageCount];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
    if (count) {
        float shadowBlurRadius = roundf(thumbnailCacheSize / 32.0);
        float shadowOffset = - ceilf(shadowBlurRadius * 0.75);
        
        PDFPage *emptyPage = [[[PDFPage alloc] init] autorelease];
        [emptyPage setBounds:[[[pdfView document] pageAtIndex:0] boundsForBox:kPDFDisplayBoxCropBox] forBox:kPDFDisplayBoxCropBox];
        NSImage *image = [emptyPage thumbnailWithSize:thumbnailCacheSize shadowBlurRadius:shadowBlurRadius shadowOffset:NSMakeSize(0.0, shadowOffset)];
        for (i = 0; i < count; i++) {
            SKThumbnail *thumbnail = [[SKThumbnail alloc] initWithImage:image label:[[pdfDoc pageAtIndex:i] label]];
            [array insertObject:thumbnail atIndex:i];
            [thumbnail release];
        }
    }
    [[self mutableArrayValueForKey:@"thumbnails"] setArray:array];
    [dirtyThumbnailIndexes removeAllIndexes];
    [dirtyThumbnailIndexes addIndexesInRange:NSMakeRange(0, count)];
    [self updateThumbnailsIfNeeded];
}

- (void)resetThumbnailSizeIfNeeded {
    float defaultSize = roundf([[NSUserDefaults standardUserDefaults] floatForKey:SKThumbnailSizeKey]);
    float thumbnailSize = (defaultSize < 32.1) ? 32.0 : (defaultSize < 64.1) ? 64.0 : (defaultSize < 128.1) ? 128.0 : 256.0;
    
    if (fabs(thumbnailSize - thumbnailCacheSize) > 0.1) {
        thumbnailCacheSize = thumbnailSize;
        
        if (thumbnailTimer) {
            [thumbnailTimer invalidate];
            [thumbnailTimer release];
            thumbnailTimer = nil;
        }
        
        if ([self countOfThumbnails])
            [self thumbnailsAtIndexesNeedUpdate:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self countOfThumbnails])]];
    }
}

- (void)thumbnailAtIndexNeedsUpdate:(unsigned)index {
    [self thumbnailsAtIndexesNeedUpdate:[NSIndexSet indexSetWithIndex:index]];
}

- (void)thumbnailsAtIndexesNeedUpdate:(NSIndexSet *)indexes {
    [dirtyThumbnailIndexes addIndexes:indexes];
    [self updateThumbnailsIfNeeded];
}

- (void)updateThumbnailsIfNeeded {
    if ([thumbnailTableView window] != nil && [dirtyThumbnailIndexes count] > 0 && thumbnailTimer == nil)
        thumbnailTimer = [[NSTimer scheduledTimerWithTimeInterval:0.03 target:self selector:@selector(updateThumbnail:) userInfo:NULL repeats:YES] retain];
}

- (void)updateThumbnail:(NSTimer *)timer {
    unsigned index = [dirtyThumbnailIndexes firstIndex];
    
    if (index != NSNotFound) {
        float shadowBlurRadius = roundf(thumbnailCacheSize / 32.0);
        float shadowOffset = - ceilf(shadowBlurRadius * 0.75);
        NSSize newSize, oldSize = [[[thumbnails objectAtIndex:index] image] size];
        
        PDFDocument *pdfDoc = [pdfView document];
        PDFPage *page = [pdfDoc pageAtIndex:index];
        NSImage *image = [page thumbnailWithSize:thumbnailCacheSize shadowBlurRadius:shadowBlurRadius shadowOffset:NSMakeSize(0.0, shadowOffset)];
        [[thumbnails objectAtIndex:index] setImage:image];
        [dirtyThumbnailIndexes removeIndex:index];
        
        newSize = [image size];
        if (fabs(newSize.width - oldSize.width) > 1.0 || fabs(newSize.height - oldSize.height) > 1.0)
            [thumbnailTableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:index]];
    }
    if ([dirtyThumbnailIndexes count] == 0) {
        [thumbnailTimer invalidate];
        [thumbnailTimer release];
        thumbnailTimer = nil;
    }
}

- (void)updateNoteSelection {

	NSArray *notes = [noteArrayController arrangedObjects];
    PDFAnnotation *annotation;
    unsigned int pageIndex = [[pdfView document] indexForPage: [pdfView currentPage]];
	int i, numRows = [notes count];
    unsigned int selPageIndex = [noteTableView numberOfSelectedRows] ? [[notes objectAtIndex:[noteTableView selectedRow]] pageIndex] : NSNotFound;
	
    if (numRows == 0 || selPageIndex == pageIndex)
		return;
	
	// Walk outline view looking for best firstpage number match.
	for (i = 0; i < numRows; i++) {
		// Get the destination of the given row....
		annotation = [notes objectAtIndex:i];
		
		if ([annotation pageIndex] == pageIndex) {
			updatingNoteSelection = YES;
			[noteTableView selectRow:i byExtendingSelection:NO];
			updatingNoteSelection = NO;
			break;
		} else if ([annotation pageIndex] > pageIndex) {
			updatingNoteSelection = YES;
			if (i < 1)				
				[noteTableView selectRow:0 byExtendingSelection:NO];
			else if ([[notes objectAtIndex:i - 1] pageIndex] != selPageIndex)
				[noteTableView selectRow:i - 1 byExtendingSelection:NO];
			updatingNoteSelection = NO;
			break;
		}
	}
}

#pragma mark Snapshots

- (void)resetSnapshotSizeIfNeeded {
    float defaultSize = roundf([[NSUserDefaults standardUserDefaults] floatForKey:SKSnapshotThumbnailSizeKey]);
    float snapshotSize = (defaultSize < 32.1) ? 32.0 : (defaultSize < 64.1) ? 64.0 : (defaultSize < 128.1) ? 128.0 : 256.0;
    
    if (fabs(snapshotSize - snapshotCacheSize) > 0.1) {
        snapshotCacheSize = snapshotSize;
        
        if (snapshotTimer) {
            [snapshotTimer invalidate];
            [snapshotTimer release];
            snapshotTimer = nil;
        }
        
        if ([self countOfSnapshots])
            [self snapshotsAtIndexesNeedUpdate:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self countOfSnapshots])]];
    }
}

- (void)snapshotAtIndexNeedsUpdate:(unsigned)index {
    [self snapshotsAtIndexesNeedUpdate:[NSIndexSet indexSetWithIndex:index]];
}

- (void)snapshotsAtIndexesNeedUpdate:(NSIndexSet *)indexes {
    [dirtySnapshotIndexes addIndexes:indexes];
    [self updateSnapshotsIfNeeded];
}

- (void)updateSnapshotsIfNeeded {
    if ([snapshotTableView window] != nil && [dirtySnapshotIndexes count] > 0 && thumbnailTimer == nil)
        snapshotTimer = [[NSTimer scheduledTimerWithTimeInterval:0.03 target:self selector:@selector(updateSnapshot:) userInfo:NULL repeats:YES] retain];
}

- (void)updateSnapshot:(NSTimer *)timer {
    unsigned index = [dirtySnapshotIndexes firstIndex];
    
    if (index != NSNotFound) {
        float shadowBlurRadius = roundf(snapshotCacheSize / 32.0);
        float shadowOffset = - ceilf(shadowBlurRadius * 0.75);
        NSSize newSize, oldSize = [[[snapshots objectAtIndex:index] thumbnail] size];
        
        SKSnapshotWindowController *controller = [snapshots objectAtIndex:index];
        NSImage *image = [controller thumbnailWithSize:snapshotCacheSize shadowBlurRadius:shadowBlurRadius shadowOffset:NSMakeSize(0.0, shadowOffset)];
        [[snapshots objectAtIndex:index] setThumbnail:image];
        [dirtySnapshotIndexes removeIndex:index];
        
        newSize = [image size];
        if (fabs(newSize.width - oldSize.width) > 1.0 || fabs(newSize.height - oldSize.height) > 1.0)
            [snapshotTableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:index]];
    }
    if ([dirtySnapshotIndexes count] == 0) {
        [snapshotTimer invalidate];
        [snapshotTimer release];
        snapshotTimer = nil;
    }
}

#pragma mark Toolbar

- (void)setupToolbar {
    // Create a new toolbar instance, and attach it to our document window
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:SKDocumentToolbarIdentifier] autorelease];
    NSToolbarItem *item;
    NSRect frame;
    
    toolbarItems = [[NSMutableDictionary alloc] initWithCapacity:9];
    
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeDefault];
    
    // We are the delegate
    [toolbar setDelegate: self];
    
    // Add template toolbar items
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarPreviousItemIdentifier];
    [item setLabel:NSLocalizedString(@"Previous", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Previous", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Go To Previous Page", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"ToolbarPrevious"]];
    [item setTarget:self];
    [item setAction:@selector(doGoToPreviousPage:)];
    [toolbarItems setObject:item forKey:SKDocumentToolbarPreviousItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarNextItemIdentifier];
    [item setLabel:NSLocalizedString(@"Next", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Next", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Go To Next Page", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"ToolbarNext"]];
    [item setTarget:self];
    [item setAction:@selector(doGoToNextPage:)];
    [toolbarItems setObject:item forKey:SKDocumentToolbarNextItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarBackForwardItemIdentifier];
    [item setLabel:NSLocalizedString(@"Back/Forward", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Back/Forward", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Back/Forward", @"Tool tip message")];
    [[backForwardButton cell] setToolTip:NSLocalizedString(@"Go Back", @"Tool tip message") forSegment:0];
    [[backForwardButton cell] setToolTip:NSLocalizedString(@"Go Forward", @"Tool tip message") forSegment:1];
    frame = [backForwardButton frame];
    frame.size.height = SEGMENTED_CONTROL_HEIGHT;
    [backForwardButton setFrame:frame];
    [item setView:backForwardButton];
    [item setMinSize:[backForwardButton bounds].size];
    [item setMaxSize:[backForwardButton bounds].size];
    [toolbarItems setObject:item forKey:SKDocumentToolbarBackForwardItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarPageNumberItemIdentifier];
    [item setLabel:NSLocalizedString(@"Page", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Page", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Go To Page", @"Tool tip message")];
    [item setView:pageNumberView];
    [item setMinSize:[pageNumberView bounds].size];
    [item setMaxSize:[pageNumberView bounds].size];
    [toolbarItems setObject:item forKey:SKDocumentToolbarPageNumberItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarScaleItemIdentifier];
    [item setLabel:NSLocalizedString(@"Scale", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Scale", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Scale", @"Tool tip message")];
    [item setView:scaleField];
    [item setMinSize:[scaleField bounds].size];
    [item setMaxSize:[scaleField bounds].size];
    [toolbarItems setObject:item forKey:SKDocumentToolbarScaleItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarZoomInItemIdentifier];
    [item setLabel:NSLocalizedString(@"Zoom In", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Zoom In", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Zoom In", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"ToolbarZoomIn"]];
    [item setTarget:self];
    [item setAction:@selector(doZoomIn:)];
    [toolbarItems setObject:item forKey:SKDocumentToolbarZoomInItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarZoomOutItemIdentifier];
    [item setLabel:NSLocalizedString(@"Zoom Out", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Zoom Out", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Zoom Out", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"ToolbarZoomOut"]];
    [item setTarget:self];
    [item setAction:@selector(doZoomOut:)];
    [toolbarItems setObject:item forKey:SKDocumentToolbarZoomOutItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarZoomActualItemIdentifier];
    [item setLabel:NSLocalizedString(@"Actual Size", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Actual Size", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Zoom To Actual Size", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"ToolbarZoomActual"]];
    [item setTarget:self];
    [item setAction:@selector(doZoomToActualSize:)];
    [toolbarItems setObject:item forKey:SKDocumentToolbarZoomActualItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarZoomAutoItemIdentifier];
    [item setLabel:NSLocalizedString(@"Zoom To Fit", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Zoom To Fit", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Zoom To Fit", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"ToolbarZoomToFit"]];
    [item setTarget:self];
    [item setAction:@selector(doZoomToFit:)];
    [toolbarItems setObject:item forKey:SKDocumentToolbarZoomAutoItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarRotateRightItemIdentifier];
    [item setLabel:NSLocalizedString(@"Rotate Right", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Rotate Right", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Rotate Right", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"ToolbarRotateRight"]];
    [item setTarget:self];
    [item setAction:@selector(rotateAllRight:)];
    [toolbarItems setObject:item forKey:SKDocumentToolbarRotateRightItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarRotateLeftItemIdentifier];
    [item setLabel:NSLocalizedString(@"Rotate Left", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Rotate Left", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Rotate Left", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"ToolbarRotateLeft"]];
    [item setTarget:self];
    [item setAction:@selector(rotateAllLeft:)];
    [toolbarItems setObject:item forKey:SKDocumentToolbarRotateLeftItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarFullScreenItemIdentifier];
    [item setLabel:NSLocalizedString(@"Full Screen", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Full Screen", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Full Screen", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"ToolbarFullScreen"]];
    [item setTarget:self];
    [item setAction:@selector(enterFullScreen:)];
    [toolbarItems setObject:item forKey:SKDocumentToolbarFullScreenItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarPresentationItemIdentifier];
    [item setLabel:NSLocalizedString(@"Presentation", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Presentation", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Presentation", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"ToolbarPresentation"]];
    [item setTarget:self];
    [item setAction:@selector(enterPresentation:)];
    [toolbarItems setObject:item forKey:SKDocumentToolbarPresentationItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarNewNoteItemIdentifier];
    [item setLabel:NSLocalizedString(@"New Note", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"New Note", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Add New Note", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"ToolbarNote"]];
    [item setTarget:self];
    [item setAction:@selector(createNewNote:)];
    [toolbarItems setObject:item forKey:SKDocumentToolbarNewNoteItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarToggleDrawerItemIdentifier];
    [item setLabel:NSLocalizedString(@"Drawer", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Drawer", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Toggle Drawer", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"ToolbarNotesDrawer"]];
    [toolbarItems setObject:item forKey:SKDocumentToolbarToggleDrawerItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarToolModeItemIdentifier];
    [item setLabel:NSLocalizedString(@"Tool Mode", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Tool Mode", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Tool Mode", @"Tool tip message")];
    [[toolModeButton cell] setToolTip:NSLocalizedString(@"Text Tool", @"Tool tip message") forSegment:SKTextToolMode];
    [[toolModeButton cell] setToolTip:NSLocalizedString(@"Scroll Tool", @"Tool tip message") forSegment:SKMoveToolMode];
    [[toolModeButton cell] setToolTip:NSLocalizedString(@"Magnify Tool", @"Tool tip message") forSegment:SKMagnifyToolMode];
    frame = [toolModeButton frame];
    frame.size.height = SEGMENTED_CONTROL_HEIGHT;
    [toolModeButton setFrame:frame];
    [item setView:toolModeButton];
    [item setMinSize:[toolModeButton bounds].size];
    [item setMaxSize:[toolModeButton bounds].size];
    [toolbarItems setObject:item forKey:SKDocumentToolbarToolModeItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarAnnotationModeItemIdentifier];
    [item setLabel:NSLocalizedString(@"Annotation", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Annotation Mode", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Annotation Mode", @"Tool tip message")];
    [[annotationModeButton cell] setToolTip:NSLocalizedString(@"Text Annotation", @"Tool tip message") forSegment:SKFreeTextAnnotationMode];
    [[annotationModeButton cell] setToolTip:NSLocalizedString(@"Note Annotation", @"Tool tip message") forSegment:SKNoteAnnotationMode];
    [[annotationModeButton cell] setToolTip:NSLocalizedString(@"Oval Annotation", @"Tool tip message") forSegment:SKCircleAnnotationMode];
    frame = [annotationModeButton frame];
    frame.size.height = SEGMENTED_CONTROL_HEIGHT;
    [annotationModeButton setFrame:frame];
    [item setView:annotationModeButton];
    [item setMinSize:[annotationModeButton bounds].size];
    [item setMaxSize:[annotationModeButton bounds].size];
    [toolbarItems setObject:item forKey:SKDocumentToolbarAnnotationModeItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarDisplayBoxItemIdentifier];
    [item setLabel:NSLocalizedString(@"Display Box", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Display Box", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Display Box", @"Tool tip message")];
    [item setView:displayBoxPopUpButton];
    [item setMinSize:[displayBoxPopUpButton bounds].size];
    [item setMaxSize:[displayBoxPopUpButton bounds].size];
    [toolbarItems setObject:item forKey:SKDocumentToolbarDisplayBoxItemIdentifier];
    [item release];
	
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarSearchItemIdentifier];
    [item setLabel:NSLocalizedString(@"Search", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Search", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Search", @"Tool tip message")];
    [item setTarget:self];
    [item setView:searchField];
    [item setMinSize:TOOLBAR_SEARCHFIELD_MIN_SIZE];
    [item setMaxSize:TOOLBAR_SEARCHFIELD_MAX_SIZE];
    [toolbarItems setObject:item forKey:SKDocumentToolbarSearchItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarInfoItemIdentifier];
    [item setLabel:NSLocalizedString(@"Info", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Info", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Get Document Info", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"ToolbarInfo"]];
    [item setTarget:self];
    [item setAction:@selector(getInfo:)];
    [toolbarItems setObject:item forKey:SKDocumentToolbarInfoItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarContentsPaneItemIdentifier];
    [item setLabel:NSLocalizedString(@"Contents Pane", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Contents Pane", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Toogle Contents Pan", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"ToolbarLeftPane"]];
    [item setTarget:self];
    [item setAction:@selector(toggleLeftSidePane:)];
    [toolbarItems setObject:item forKey:SKDocumentToolbarContentsPaneItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarNotesPaneItemIdentifier];
    [item setLabel:NSLocalizedString(@"Notes Pane", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Notes Pane", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Toogle Notes Pan", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"ToolbarRightPane"]];
    [item setTarget:self];
    [item setAction:@selector(toggleRightSidePane:)];
    [toolbarItems setObject:item forKey:SKDocumentToolbarNotesPaneItemIdentifier];
    [item release];
    
    // Attach the toolbar to the window
    [[self window] setToolbar:toolbar];
}

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {

    NSToolbarItem *item = [toolbarItems objectForKey:itemIdent];
    NSToolbarItem *newItem = [[item copy] autorelease];
    // the view should not be copied
    if ([item view] && willBeInserted) [newItem setView:[item view]];
    return newItem;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return [NSArray arrayWithObjects:
        SKDocumentToolbarPreviousItemIdentifier, 
        SKDocumentToolbarNextItemIdentifier, 
        SKDocumentToolbarPageNumberItemIdentifier, 
        SKDocumentToolbarBackForwardItemIdentifier, 
		NSToolbarSeparatorItemIdentifier, 
        SKDocumentToolbarZoomInItemIdentifier, 
        SKDocumentToolbarZoomOutItemIdentifier, 
        SKDocumentToolbarToolModeItemIdentifier, nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return [NSArray arrayWithObjects: 
        SKDocumentToolbarPreviousItemIdentifier, 
        SKDocumentToolbarNextItemIdentifier, 
        SKDocumentToolbarBackForwardItemIdentifier, 
        SKDocumentToolbarPageNumberItemIdentifier, 
        SKDocumentToolbarScaleItemIdentifier, 
        SKDocumentToolbarZoomInItemIdentifier, 
        SKDocumentToolbarZoomOutItemIdentifier, 
        SKDocumentToolbarZoomActualItemIdentifier, 
        SKDocumentToolbarZoomAutoItemIdentifier, 
        SKDocumentToolbarRotateRightItemIdentifier, 
        SKDocumentToolbarRotateLeftItemIdentifier, 
        SKDocumentToolbarFullScreenItemIdentifier, 
        SKDocumentToolbarPresentationItemIdentifier, 
        SKDocumentToolbarNewNoteItemIdentifier, 
        SKDocumentToolbarInfoItemIdentifier, 
        SKDocumentToolbarContentsPaneItemIdentifier, 
        SKDocumentToolbarNotesPaneItemIdentifier, 
        SKDocumentToolbarToolModeItemIdentifier, 
        SKDocumentToolbarAnnotationModeItemIdentifier, 
        SKDocumentToolbarDisplayBoxItemIdentifier, 
		NSToolbarPrintItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier, 
		NSToolbarSpaceItemIdentifier, 
		NSToolbarSeparatorItemIdentifier, 
		NSToolbarCustomizeToolbarItemIdentifier, nil];
}

#pragma mark UI validation

- (BOOL)validateToolbarItem:(NSToolbarItem *) toolbarItem {
    NSString *identifier = [toolbarItem itemIdentifier];
    if ([identifier isEqualToString:SKDocumentToolbarPreviousItemIdentifier]) {
        return [pdfView canGoToPreviousPage];
    } else if ([identifier isEqualToString:SKDocumentToolbarNextItemIdentifier]) {
        return [pdfView canGoToNextPage];
    } else if ([identifier isEqualToString:SKDocumentToolbarZoomInItemIdentifier]) {
        return [pdfView canZoomIn];
    } else if ([identifier isEqualToString:SKDocumentToolbarZoomAutoItemIdentifier]) {
        return [pdfView autoScales] == NO;
    } else if ([identifier isEqualToString:SKDocumentToolbarZoomActualItemIdentifier]) {
        return fabs([pdfView scaleFactor] - 1.0) > 0.01;
    } else if ([identifier isEqualToString:SKDocumentToolbarFullScreenItemIdentifier]) {
        return YES;
    } else if ([identifier isEqualToString:SKDocumentToolbarPresentationItemIdentifier]) {
        return YES;
    } else if ([identifier isEqualToString:SKDocumentToolbarInfoItemIdentifier]) {
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = [menuItem action];
    if (action == @selector(createNewNote:)) {
        return [pdfView toolMode] == SKTextToolMode;
    } else if (action == @selector(displaySinglePages:)) {
        BOOL displaySinglePages = [pdfView displayMode] == kPDFDisplaySinglePage || [pdfView displayMode] == kPDFDisplaySinglePageContinuous;
        [menuItem setState:displaySinglePages ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(displayFacingPages:)) {
        BOOL displayFacingPages = [pdfView displayMode] == kPDFDisplayTwoUp || [pdfView displayMode] == kPDFDisplayTwoUpContinuous;
        [menuItem setState:displayFacingPages ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(toggleDisplayContinuous:)) {
        BOOL displayContinuous = [pdfView displayMode] == kPDFDisplaySinglePageContinuous || [pdfView displayMode] == kPDFDisplayTwoUpContinuous;
        [menuItem setState:displayContinuous ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(toggleDisplayAsBook:)) {
        [menuItem setState:[pdfView displaysAsBook] ? NSOnState : NSOffState];
        return [pdfView displayMode] == kPDFDisplayTwoUp || [pdfView displayMode] == kPDFDisplayTwoUpContinuous;
    } else if (action == @selector(toggleDisplayPageBreaks:)) {
        [menuItem setState:[pdfView displaysPageBreaks] ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(displayMediaBox:)) {
        BOOL displayMediaBox = [pdfView displayBox] == kPDFDisplayBoxMediaBox;
        [menuItem setState:displayMediaBox ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(displayCropBox:)) {
        BOOL displayCropBox = [pdfView displayBox] == kPDFDisplayBoxCropBox;
        [menuItem setState:displayCropBox ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(changeToolMode:)) {
        [menuItem setState:[pdfView toolMode] == (unsigned)[menuItem tag] ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(changeAnnotationMode:)) {
        [menuItem setState:[pdfView annotationMode] == (unsigned)[menuItem tag] ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(doGoToNextPage:)) {
        return [pdfView canGoToNextPage];
    } else if (action == @selector(doGoToPreviousPage:)) {
        return [pdfView canGoToPreviousPage];
    } else if (action == @selector(doGoBack:)) {
        return [pdfView canGoBack];
    } else if (action == @selector(doGoForward:)) {
        return [pdfView canGoForward];
    } else if (action == @selector(doZoomIn:)) {
        return [pdfView canZoomIn];
    } else if (action == @selector(doZoomOut:)) {
        return [pdfView canZoomOut];
    } else if (action == @selector(doZoomToActualSize:)) {
        return fabs([pdfView scaleFactor] - 1.0 ) > 0.01;
    } else if (action == @selector(doZoomToFit:)) {
        return [pdfView autoScales] == NO;
    } else if (action == @selector(toggleLeftSidePane:)) {
        if (NSWidth([leftSideContentBox frame]) > 0.0)
            [menuItem setTitle:NSLocalizedString(@"Hide Contents Pane", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Contents Pane", @"Menu item title")];
        return [self isFullScreen] == NO && [self isPresentation] == NO;
    } else if (action == @selector(toggleRightSidePane:)) {
        if (NSWidth([rightSideContentBox frame]) > 0.0)
            [menuItem setTitle:NSLocalizedString(@"Hide Notes Pane", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Notes Pane", @"Menu item title")];
        return [self isFullScreen] == NO && [self isPresentation] == NO;
    } else if (action == @selector(changeLeftSidePaneState:)) {
        [menuItem setState:(int)leftSidePaneState == [menuItem tag] ? ([findTableView window] ? NSMixedState : NSOnState) : NSOffState];
        return YES;
    } else if (action == @selector(changeRightSidePaneState:)) {
        [menuItem setState:(int)rightSidePaneState == [menuItem tag] ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(toggleFullScreen:)) {
        return YES;
    } else if (action == @selector(togglePresentation:)) {
        return YES;
    } else if (action == @selector(getInfo:)) {
        return YES;
    }
    return YES;
}

#pragma mark SKSplitView delegate protocol

- (void)splitView:(SKSplitView *)sender doubleClickedDividerAt:(int)offset{
    if (offset == 0)
        [self toggleLeftSidePane:self];
    else
        [self toggleRightSidePane:self];
}

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize {
    NSView *leftSideView = [[sender subviews] objectAtIndex:0];
    NSView *mainView = [[sender subviews] objectAtIndex:1]; // pdfView
    NSView *rightSideView = [[sender subviews] objectAtIndex:2];
    NSRect leftSideFrame = [leftSideView frame];
    NSRect mainFrame = [mainView frame];
    NSRect rightSideFrame = [rightSideView frame];
    
    if (NSWidth(leftSideFrame) <= 1.0)
        leftSideFrame.size.width = 0.0;
    if (NSWidth(rightSideFrame) <= 1.0)
        rightSideFrame.size.width = 0.0;
    
    mainFrame.size.width = NSWidth([sender frame]) - NSWidth(leftSideFrame) - NSWidth(rightSideFrame) - 2 * [sender dividerThickness];
    
    if (NSWidth(mainFrame) < 0.0) {
        float resizeFactor = 1.0 + NSWidth(mainFrame) / (NSWidth(leftSideFrame) + NSWidth(rightSideFrame));
        leftSideFrame.size.width = floorf(resizeFactor * NSWidth(leftSideFrame));
        rightSideFrame.size.width = floorf(resizeFactor * NSWidth(rightSideFrame));
        mainFrame.size.width = NSWidth([sender frame]) - NSWidth(leftSideFrame) - NSWidth(rightSideFrame) - 2 * [sender dividerThickness];
    }
    
    [leftSideView setFrame:leftSideFrame];
    [rightSideView setFrame:rightSideFrame];
    [mainView setFrame:mainFrame];
    
    [sender adjustSubviews];
}

@end

#pragma mark -

// the search table columns use these methods for display
@interface PDFSelection (SKExtensions)
@end

@implementation PDFSelection (SKExtensions)

// returns the label of the first page (if the selection spans multiple pages)
- (NSString *)firstPageLabel { 
    NSArray *pages = [self pages];
    return [pages count] ? [[pages objectAtIndex:0] label] : nil;
}

- (NSAttributedString *)contextString {
    PDFSelection *extendedSelection = [self copy]; // see remark in -tableViewSelectionDidChange:
	NSMutableAttributedString *attributedSample;
	NSString *searchString = [[self string] stringByCollapsingWhitespaceAndNewlinesAndRemovingSurroundingWhitespaceAndNewlines];
	NSString *sample;
    NSMutableString *attributedString;
	NSString *ellipse = [NSString stringWithFormat:@"%C", 0x2026];
	NSRange foundRange;
    NSDictionary *attributes;
	NSMutableParagraphStyle *paragraphStyle = nil;
	
	// Extend selection.
	[extendedSelection extendSelectionAtStart:10];
	[extendedSelection extendSelectionAtEnd:20];
	
    // get the cleaned string
    sample = [[extendedSelection string] stringByCollapsingWhitespaceAndNewlinesAndRemovingSurroundingWhitespaceAndNewlines];
    
	// Finally, create attributed string.
 	attributedSample = [[NSMutableAttributedString alloc] initWithString:sample];
    attributedString = [attributedSample mutableString];
    [attributedString insertString:ellipse atIndex:0];
    [attributedString appendString:ellipse];
	
	// Find instances of search string and "bold" them.
	foundRange = [sample rangeOfString:searchString options:NSCaseInsensitiveSearch];
    if (foundRange.location != NSNotFound) {
        // Bold the text range where the search term was found.
        attributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]], NSFontAttributeName, nil];
        [attributedSample setAttributes:attributes range:NSMakeRange(foundRange.location + 1, foundRange.length)];
        [attributes release];
    }
    
	// Create paragraph style that indicates truncation style.
	paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	attributes = [[NSDictionary alloc] initWithObjectsAndKeys:paragraphStyle, NSParagraphStyleAttributeName, nil];
	// Add paragraph style.
    [attributedSample addAttributes:attributes range:NSMakeRange(0, [attributedSample length])];
	// Clean.
	[attributes release];
	[paragraphStyle release];
	[extendedSelection release];
	
	return [attributedSample autorelease];
}

@end

#pragma mark -

@implementation SKNoteTableView

- (void)delete:(id)sender {
    if ([[self delegate] respondsToSelector:@selector(tableView:deleteRowsWithIndexes:)]) {
		if ([self selectedRow] == -1)
			NSBeep();
		else
			[[self delegate] tableView:self deleteRowsWithIndexes:[self selectedRowIndexes]];
    }
}

- (void)keyDown:(NSEvent *)theEvent {
    NSString *characters = [theEvent charactersIgnoringModifiers];
    unichar eventChar = [characters length] > 0 ? [characters characterAtIndex:0] : 0;
	unsigned int modifiers = [theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask;
    
	if ((eventChar == NSDeleteCharacter || eventChar == NSDeleteFunctionKey) && modifiers == 0)
        [self delete:self];
	else
		[super keyDown:theEvent];
}

@end

#pragma mark -

@implementation SKSnapshotTableView

- (void)setFrame:(NSRect)frameRect {
    [super setFrame:frameRect];
    [self noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfRows])]];
}

- (void)setFrameSize:(NSSize)frameSize {
    [super setFrameSize:frameSize];
    [self noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfRows])]];
}

@end

#pragma mark -

@implementation SKThumbnailTableView

- (void)setFrame:(NSRect)frameRect {
    [super setFrame:frameRect];
    [self noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfRows])]];
}

- (void)setFrameSize:(NSSize)frameSize {
    [super setFrameSize:frameSize];
    [self noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfRows])]];
}

- (void)highlightSelectionInClipRect:(NSRect)clipRect {
    NSMutableIndexSet *rowIndexes = [[[self selectedRowIndexes] mutableCopy] autorelease];
    NSArray *rows = [[self delegate] tableViewHighlightedRows:self];
    NSColor *color = ([[self window] isKeyWindow] && [[self window] firstResponder] == self) ? [NSColor alternateSelectedControlColor] : [NSColor secondarySelectedControlColor];
    float factor = 0.5;
    int i, count = [rows count];
    
    [NSGraphicsContext saveGraphicsState];
    for (i = 0; i < count; i++) {
        int row = [[rows objectAtIndex:i] intValue];
        [[[NSColor controlBackgroundColor] blendedColorWithFraction:factor ofColor:color] set];
        factor /= 2.0;
        if ([rowIndexes containsIndex:row] == NO) {
            NSRectFill([self rectOfRow:row]);
            [rowIndexes addIndex:row];
        }
    }
    [NSGraphicsContext restoreGraphicsState];
    
    [super highlightSelectionInClipRect:clipRect]; 
}

@end

#pragma mark -

@implementation SKOutlineView

- (void)highlightSelectionInClipRect:(NSRect)clipRect {
    NSMutableIndexSet *rowIndexes = [[[self selectedRowIndexes] mutableCopy] autorelease];
    NSArray *rows = [[self delegate] outlineViewHighlightedRows:self];
    NSColor *color = ([[self window] isKeyWindow] && [[self window] firstResponder] == self) ? [NSColor alternateSelectedControlColor] : [NSColor secondarySelectedControlColor];
    float factor = 0.5;
    int i, count = [rows count];
    
    [NSGraphicsContext saveGraphicsState];
    for (i = 0; i < count; i++) {
        int row = [[rows objectAtIndex:i] intValue];
        [[[NSColor controlBackgroundColor] blendedColorWithFraction:factor ofColor:color] set];
        factor /= 2.0;
        if ([rowIndexes containsIndex:row] == NO) {
            NSRectFill([self rectOfRow:row]);
            [rowIndexes addIndex:row];
        }
    }
    [NSGraphicsContext restoreGraphicsState];
    
    [super highlightSelectionInClipRect:clipRect]; 
}

@end

#pragma mark -

@implementation NSUserDefaultsController (SKExtensions)

- (void)addObserver:(NSObject *)anObserver forKey:(NSString *)key {
    [self addObserver:anObserver forKeyPath:[NSString stringWithFormat:@"values.%@", key] options:0 context:NULL];
}

- (void)removeObserver:(NSObject *)anObserver forKey:(NSString *)key {
    [self removeObserver:anObserver forKeyPath:[NSString stringWithFormat:@"values.%@", key]];
}

@end
