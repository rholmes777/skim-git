//
//  SKSnapshotPageCell.m
//  Skim
//
//  Created by Christiaan Hofman on 4/10/08.
/*
 This software is Copyright (c) 2008-2011
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

#import "SKSnapshotPageCell.h"
#import "SKDictionaryFormatter.h"
#import "NSGeometry_SKExtensions.h"

NSString *SKSnapshotPageCellLabelKey = @"label";
NSString *SKSnapshotPageCellHasWindowKey = @"hasWindow";

@implementation SKSnapshotPageCell

static SKDictionaryFormatter *snapshotPageCellFormatter = nil;

+ (void)initialize {
    SKINITIALIZE;
    snapshotPageCellFormatter = [[SKDictionaryFormatter alloc] init];
    [snapshotPageCellFormatter setKey:SKSnapshotPageCellLabelKey];
}

- (id)initTextCell:(NSString *)aString {
    self = [super initTextCell:aString];
    if (self) {
        [self setFormatter:snapshotPageCellFormatter];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super initWithCoder:decoder];
    if (self) {
        if ([self formatter] == nil)
            [self setFormatter:snapshotPageCellFormatter];
	}
	return self;
}

- (NSSize)cellSizeForBounds:(NSRect)aRect {
    NSSize size = [super cellSizeForBounds:aRect];
    size.width = fmin(fmax(size.width, 16.0), NSWidth(aRect));
    return size;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSRect textRect, imageRect;
    NSDivideRect(cellFrame, &textRect, &imageRect, 17.0, NSMinYEdge);
    
    [super drawInteriorWithFrame:textRect inView:controlView];
    
    id obj = [self objectValue];
    BOOL hasWindow = [obj respondsToSelector:@selector(objectForKey:)] ? [[obj objectForKey:SKSnapshotPageCellHasWindowKey] boolValue] : NO;
    if (hasWindow) {
        CGFloat radius = 2.0;
        NSBezierPath *path = [NSBezierPath bezierPath];
        NSShadow *aShadow = [[[NSShadow alloc] init] autorelease];
        NSColor *fillColor;
        
        switch ([self interiorBackgroundStyle]) {
            case NSBackgroundStyleDark:
                [aShadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.2]];
                fillColor = [NSColor colorWithCalibratedWhite:1.0 alpha:1.0];
                break;
            case NSBackgroundStyleLowered:
                [aShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.3333]];
                fillColor = [NSColor colorWithCalibratedWhite:1.0 alpha:1.0];
                break;
            case NSBackgroundStyleRaised:
                [aShadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.3]];
                fillColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.8];
                break;
            case NSBackgroundStyleLight:
            default:
                [aShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.2]];
                fillColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.8];
                break;
        }
        [aShadow setShadowOffset:NSMakeSize(0.0, -1.0)];
        
        imageRect = SKSliceRect(imageRect, 10.0, NSMinYEdge);
        imageRect.origin.x += 4.0;
        imageRect.size.width = 10.0;
        
        [path moveToPoint:NSMakePoint(NSMinX(imageRect), NSMaxY(imageRect))];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(imageRect) + radius, NSMinY(imageRect) + radius) radius:radius startAngle:180.0 endAngle:270.0];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(imageRect) - radius, NSMinY(imageRect) + radius) radius:radius startAngle:270.0 endAngle:360.0];
        [path lineToPoint:NSMakePoint(NSMaxX(imageRect), NSMaxY(imageRect))];
        [path closePath];
        
        imageRect = NSInsetRect(imageRect, 1.0, 2.0);
        imageRect.size.height += 1.0;
        
        [path appendBezierPath:[NSBezierPath bezierPathWithRect:imageRect]];
        [path setWindingRule:NSEvenOddWindingRule];
        
        [NSGraphicsContext saveGraphicsState];
        
        [aShadow set];
        [fillColor setFill];

        [path fill];
        
        [NSGraphicsContext restoreGraphicsState];
    }
}

@end
