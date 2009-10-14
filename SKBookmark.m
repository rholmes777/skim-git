//
//  SKBookmark.m
//  Skim
//
//  Created by Christiaan Hofman on 9/15/07.
/*
 This software is Copyright (c) 2007-2009
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "SKBookmark.h"
#import "BDAlias.h"
#import "NSImage_SKExtensions.h"
#import "SKRuntime.h"

#define BOOKMARK_STRING     @"bookmark"
#define SESSION_STRING      @"session"
#define FOLDER_STRING       @"folder"
#define SEPARATOR_STRING    @"separator"

#define PROPERTIES_KEY  @"properties"
#define CHILDREN_KEY    @"children"
#define LABEL_KEY       @"label"
#define PAGEINDEX_KEY   @"pageIndex"
#define ALIASDATA_KEY   @"_BDAlias"
#define TYPE_KEY        @"type"

@interface SKPlaceholderBookmark : SKBookmark
@end

@interface SKFileBookmark : SKBookmark {
    BDAlias *alias;
    NSData *aliasData;
    NSString *label;
    NSUInteger pageIndex;
    NSDictionary *setup;
}
- (id)initWithAlias:(BDAlias *)anAlias pageIndex:(NSUInteger)aPageIndex label:(NSString *)aLabel;
- (BDAlias *)alias;
- (NSData *)aliasData;
@end

@interface SKFolderBookmark : SKBookmark {
    NSString *label;
    NSMutableArray *children;
}
@end

@interface SKSessionBookmark : SKFolderBookmark
@end

@interface SKSeparatorBookmark : SKBookmark
@end

#pragma mark -

@implementation SKBookmark

static SKPlaceholderBookmark *defaultPlaceholderBookmark = nil;
static Class SKBookmarkClass = Nil;

+ (void)initialize {
    SKINITIALIZE;
    SKBookmarkClass = self;
    defaultPlaceholderBookmark = (SKPlaceholderBookmark *)NSAllocateObject([SKPlaceholderBookmark class], 0, NSDefaultMallocZone());
}

+ (id)allocWithZone:(NSZone *)aZone {
    return SKBookmarkClass == self ? defaultPlaceholderBookmark : [super allocWithZone:aZone];
}

+ (id)bookmarkWithPath:(NSString *)aPath pageIndex:(NSUInteger)aPageIndex label:(NSString *)aLabel {
    return [[[self alloc] initWithPath:aPath pageIndex:aPageIndex label:aLabel] autorelease];
}

+ (id)bookmarkWithSetup:(NSDictionary *)aSetupDict label:(NSString *)aLabel {
    return [[[self alloc] initWithSetup:aSetupDict label:aLabel] autorelease];
}

+ (id)bookmarkFolderWithChildren:(NSArray *)aChildren label:(NSString *)aLabel {
    return [[[self alloc] initFolderWithChildren:aChildren label:aLabel] autorelease];
}

+ (id)bookmarkFolderWithLabel:(NSString *)aLabel {
    return [[[self alloc] initFolderWithLabel:aLabel] autorelease];
}

+ (id)bookmarkSessionWithChildren:(NSArray *)aChildren label:(NSString *)aLabel {
    return [[[self alloc] initSessionWithChildren:aChildren label:aLabel] autorelease];
}

+ (id)bookmarkSeparator {
    return [[[self alloc] initSeparator] autorelease];
}

+ (id)bookmarkWithProperties:(NSDictionary *)dictionary {
    return [[[self alloc] initWithProperties:dictionary] autorelease];
}

- (id)initWithPath:(NSString *)aPath pageIndex:(NSUInteger)aPageIndex label:(NSString *)aLabel {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithSetup:(NSDictionary *)aSetupDict label:(NSString *)aLabel {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initFolderWithChildren:(NSArray *)aChildren label:(NSString *)aLabel {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initFolderWithLabel:(NSString *)aLabel {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initSessionWithChildren:(NSArray *)aChildren label:(NSString *)aLabel {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initSeparator {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithProperties:(NSDictionary *)dictionary {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)copyWithZone:(NSZone *)aZone {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (NSDictionary *)properties { return nil; }

- (NSInteger)bookmarkType { return SKBookmarkTypeSeparator; }

- (NSImage *)icon { return nil; }

- (NSString *)label { return nil; }
- (void)setLabel:(NSString *)newLabel {}

- (NSString *)path { return nil; }
- (NSUInteger)pageIndex { return NSNotFound; }
- (NSNumber *)pageNumber { return nil; }

- (NSArray *)session { return nil; }

- (NSArray *)children { return nil; }
- (NSUInteger)countOfChildren { return 0; }
- (SKBookmark *)objectInChildrenAtIndex:(NSUInteger)anIndex { return nil; }
- (void)insertObject:(SKBookmark *)child inChildrenAtIndex:(NSUInteger)anIndex {}
- (void)removeObjectFromChildrenAtIndex:(NSUInteger)anIndex {}

- (SKBookmark *)parent {
    return parent;
}

- (void)setParent:(SKBookmark *)newParent {
    parent = newParent;
}

- (BOOL)isDescendantOf:(SKBookmark *)bookmark {
    if (self == bookmark)
        return YES;
    for (SKBookmark *child in [bookmark children]) {
        if ([self isDescendantOf:child])
            return YES;
    }
    return NO;
}

- (BOOL)isDescendantOfArray:(NSArray *)bookmarks {
    for (SKBookmark *bm in bookmarks) {
        if ([self isDescendantOf:bm]) return YES;
    }
    return NO;
}

@end

#pragma mark -

@implementation SKPlaceholderBookmark

- (id)init {
    return nil;
}

- (id)initWithAlias:(BDAlias *)anAlias pageIndex:(NSUInteger)aPageIndex label:(NSString *)aLabel {
    return [[SKFileBookmark alloc] initWithAlias:anAlias pageIndex:aPageIndex label:aLabel];
}

- (id)initWithPath:(NSString *)aPath pageIndex:(NSUInteger)aPageIndex label:(NSString *)aLabel {
    return [[SKFileBookmark alloc] initWithAlias:[BDAlias aliasWithPath:aPath] pageIndex:aPageIndex label:aLabel];
}

- (id)initWithSetup:(NSDictionary *)aSetupDict label:(NSString *)aLabel {
    return [[SKFileBookmark alloc] initWithSetup:aSetupDict label:aLabel];
}

- (id)initFolderWithChildren:(NSArray *)aChildren label:(NSString *)aLabel {
    return [[SKFolderBookmark alloc] initFolderWithChildren:aChildren label:aLabel];
}

- (id)initFolderWithLabel:(NSString *)aLabel {
    return [self initFolderWithChildren:nil label:aLabel];
}

- (id)initSessionWithChildren:(NSArray *)aChildren label:(NSString *)aLabel {
    return [[SKSessionBookmark alloc] initFolderWithChildren:aChildren label:aLabel];
}

- (id)initSeparator {
    return [[SKSeparatorBookmark alloc] init];
}

- (id)initWithProperties:(NSDictionary *)dictionary {
    NSString *type = [dictionary objectForKey:TYPE_KEY];
    if ([type isEqualToString:SEPARATOR_STRING]) {
        return [[SKSeparatorBookmark alloc] init];
    } else if ([type isEqualToString:FOLDER_STRING] || [type isEqualToString:SESSION_STRING]) {
        Class bookmarkClass = [type isEqualToString:FOLDER_STRING] ? [SKFolderBookmark class] : [SKSessionBookmark class];
        NSMutableArray *newChildren = [NSMutableArray array];
        for (NSDictionary *dict in [dictionary objectForKey:CHILDREN_KEY])
            [newChildren addObject:[SKBookmark bookmarkWithProperties:dict]];
        return [[bookmarkClass alloc] initFolderWithChildren:newChildren label:[dictionary objectForKey:LABEL_KEY]];
    } else if ([dictionary objectForKey:@"windowFrame"]) {
        return [[SKFileBookmark alloc] initWithSetup:dictionary label:[dictionary objectForKey:LABEL_KEY]];
    } else {
        return [[SKFileBookmark alloc] initWithAlias:[BDAlias aliasWithData:[dictionary objectForKey:ALIASDATA_KEY]] pageIndex:[[dictionary objectForKey:PAGEINDEX_KEY] unsignedIntegerValue] label:[dictionary objectForKey:LABEL_KEY]];
    }
}

- (id)retain { return self; }

- (id)autorelease { return self; }

- (void)release {}

- (NSUInteger)retainCount { return NSUIntegerMax; }

@end

#pragma mark -

@implementation SKFileBookmark

+ (NSImage *)missingFileImage {
    static NSImage *image = nil;
    if (image == nil) {
        image = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
        NSImage *genericDocImage = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
        NSImage *questionMark = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kQuestionMarkIcon)];
        NSImage *tmpImage = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
        [tmpImage lockFocus];
        [genericDocImage drawInRect:NSMakeRect(0.0, 0.0, 32.0, 32.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:0.7];
        [questionMark drawInRect:NSMakeRect(6.0, 4.0, 20.0, 20.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.7];
        [tmpImage unlockFocus];
        [image addRepresentation:[[tmpImage representations] lastObject]];
        [tmpImage release];
        tmpImage = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
        [tmpImage lockFocus];
        [genericDocImage drawInRect:NSMakeRect(0.0, 0.0, 16.0, 16.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:0.7];
        [questionMark drawInRect:NSMakeRect(3.0, 2.0, 10.0, 10.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.7];
        [tmpImage unlockFocus];
        [image addRepresentation:[[tmpImage representations] lastObject]];
        [tmpImage release];
    }
    return image;
}

- (id)initWithAlias:(BDAlias *)anAlias pageIndex:(NSUInteger)aPageIndex label:(NSString *)aLabel {
    if (self = [super init]) {
        if (anAlias) {
            alias = [anAlias retain];
            aliasData = [[alias aliasData] retain];
            pageIndex = aPageIndex;
            label = [aLabel copy];
            setup = nil;
        } else {
            [self release];
            self = nil;
        }
    }
    return self;
}

- (id)initWithSetup:(NSDictionary *)aSetupDict label:(NSString *)aLabel {
    if (self = [self initWithAlias:[BDAlias aliasWithData:[aSetupDict objectForKey:ALIASDATA_KEY]] pageIndex:[[aSetupDict objectForKey:PAGEINDEX_KEY] unsignedIntegerValue] label:aLabel]) {
        setup = [aSetupDict copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)aZone {
    return [[[self class] allocWithZone:aZone] initWithAlias:alias pageIndex:pageIndex label:label];
}

- (void)dealloc {
    [alias release];
    [aliasData release];
    [label release];
    [setup release];
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: label=%@, path=%@, page=%lu>", [self class], label, [self path], (unsigned long)pageIndex];
}

- (NSDictionary *)properties {
    NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithDictionary:setup];
    [properties addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:BOOKMARK_STRING, TYPE_KEY, [self aliasData], ALIASDATA_KEY, [NSNumber numberWithUnsignedInteger:pageIndex], PAGEINDEX_KEY, label, LABEL_KEY, nil]];
    return properties;
}

- (NSInteger)bookmarkType {
    return SKBookmarkTypeBookmark;
}

- (NSString *)path {
    return [alias fullPathNoUI];
}

- (BDAlias *)alias {
    return alias;
}

- (NSData *)aliasData {
    return [self path] ? [alias aliasData] : aliasData;
}

- (NSImage *)icon {
    NSString *filePath = [self path];
    return filePath ? [[NSWorkspace sharedWorkspace] iconForFile:filePath] : [[self class] missingFileImage];
}

- (NSUInteger)pageIndex {
    return pageIndex;
}

- (NSNumber *)pageNumber {
    return pageIndex == NSNotFound ? nil : [NSNumber numberWithUnsignedInteger:pageIndex + 1];
}

- (NSString *)label {
    return label ?: @"";
}

- (void)setLabel:(NSString *)newLabel {
    if (label != newLabel) {
        [label release];
        label = [newLabel retain];
    }
}

@end

#pragma mark -

@implementation SKFolderBookmark

- (id)initFolderWithChildren:(NSArray *)aChildren label:(NSString *)aLabel {
    if (self = [super init]) {
        label = [aLabel copy];
        children = [[NSMutableArray alloc] initWithArray:aChildren];
        [children makeObjectsPerformSelector:@selector(setParent:) withObject:self];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)aZone {
    return [[[self class] allocWithZone:aZone] initFolderWithChildren:[[[NSArray alloc] initWithArray:children copyItems:YES] autorelease] label:label];
}

- (void)dealloc {
    [label release];
    [children release];
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: label=%@, children=%@>", [self class], label, children];
}

- (NSDictionary *)properties {
    return [NSDictionary dictionaryWithObjectsAndKeys:FOLDER_STRING, TYPE_KEY, [children valueForKey:PROPERTIES_KEY], CHILDREN_KEY, label, LABEL_KEY, nil];
}

- (NSInteger)bookmarkType {
    return SKBookmarkTypeFolder;
}

- (NSImage *)icon {
    return [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)];
}

- (NSString *)label {
    return label ?: @"";
}

- (void)setLabel:(NSString *)newLabel {
    if (label != newLabel) {
        [label release];
        label = [newLabel retain];
    }
}

- (NSArray *)children {
    return [[children copy] autorelease];
}

- (NSUInteger)countOfChildren {
    return [children count];
}

- (SKBookmark *)objectInChildrenAtIndex:(NSUInteger)anIndex {
    return [children objectAtIndex:anIndex];
}

- (void)insertObject:(SKBookmark *)child inChildrenAtIndex:(NSUInteger)anIndex {
    [children insertObject:child atIndex:anIndex];
    [child setParent:self];
}

- (void)removeObjectFromChildrenAtIndex:(NSUInteger)anIndex {
    [[children objectAtIndex:anIndex] setParent:nil];
    [children removeObjectAtIndex:anIndex];
}

@end

#pragma mark -

@implementation SKSessionBookmark

- (NSDictionary *)properties {
    return [NSDictionary dictionaryWithObjectsAndKeys:SESSION_STRING, TYPE_KEY, [children valueForKey:PROPERTIES_KEY], CHILDREN_KEY, label, LABEL_KEY, nil];
}

- (NSInteger)bookmarkType {
    return SKBookmarkTypeSession;
}

- (NSImage *)icon {
    return [NSImage imageNamed:NSImageNameMultipleDocuments];
}

@end

#pragma mark -

@implementation SKSeparatorBookmark

- (id)copyWithZone:(NSZone *)aZone {
    return [[[self class] allocWithZone:aZone] init];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: separator>", [self class]];
}

- (NSDictionary *)properties {
    return [NSDictionary dictionaryWithObjectsAndKeys:SEPARATOR_STRING, TYPE_KEY, nil];
}

- (NSInteger)bookmarkType {
    return SKBookmarkTypeSeparator;
}

@end
