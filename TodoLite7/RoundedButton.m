//
//  RoundedButton.m
//  ToDoLite
//
//  Created by Pasin Suriyentrakorn on 4/8/14.
//  Copyright (c) 2014 Chris Anderson. All rights reserved.
//

#import "RoundedButton.h"

@implementation RoundedButton

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        
    }
    return self;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    if (!self.layer.mask) {
        [self addCircleMaskToBounds:frame];
    }
}

- (void)addCircleMaskToBounds:(CGRect)maskBounds {
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    
    maskLayer.bounds = maskBounds;
    maskLayer.path = CGPathCreateWithEllipseInRect(maskBounds, NULL);
    maskLayer.position = CGPointMake(maskBounds.size.width/2, maskBounds.size.height/2);
    
    maskLayer.shouldRasterize = YES;
    maskLayer.rasterizationScale = [UIScreen mainScreen].scale;
    
    self.layer.mask = maskLayer;
}

@end
