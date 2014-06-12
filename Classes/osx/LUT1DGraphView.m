//
//  LUT1DGraphView.m
//  Pods
//
//  Created by Greg Cotten on 5/1/14.
//
//

#import "LUT1DGraphView.h"

@interface LUT1DGraphView ()

@property (strong) NSArray *cubicSplinesRGBArray;
@property (strong) NSArray *lerpRGBArray;

@property (assign) double minimumOutputValue;
@property (assign) double maximumOutputValue;




@end

@implementation LUT1DGraphViewController

- (void)initialize{
    [self.graphView addObserver:self forKeyPath:@"mousePoint" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)dealloc{
    [self.graphView removeObserver:self forKeyPath:@"mousePoint"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if([keyPath isEqualToString:@"mousePoint"]){
        self.colorStringAtMousePoint = [self.graphView colorStringFromCurrentMousePoint];
    }
}

- (void)setViewWithLUT:(LUT1D *)lut{
    self.graphView.lut = lut;
}

- (void)setInterpolation:(LUT1DGraphViewInterpolation)interpolation{
    self.graphView.interpolation = interpolation;
}

@end

@implementation LUT1DGraphView

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initialize];
    }
    return self;
}


- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initialize];
    }
    return self;
}



-(void)initialize{
    self.interpolation = LUT1DGraphViewInterpolationLinear;
    [self lutDidChange];
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                options: (NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInKeyWindow )
                                                  owner:self userInfo:nil];
    [self addTrackingArea:trackingArea];
    
}

-(void)mouseMoved:(NSEvent *)theEvent{
    self.mousePoint = theEvent.locationInWindow;
    [self setNeedsDisplay:YES];
}

-(void)setLut:(LUT1D *)lut{
    _lut = lut;
    [self lutDidChange];
    
}

-(void)setInterpolation:(LUT1DGraphViewInterpolation)interpolation{
    if(interpolation != _interpolation){
        _interpolation = interpolation;
        [self setNeedsDisplay:YES];
    }
    //no need to redraw if the interpolation didn't actually change!
}

-(void)lutDidChange{
    if(self.lut){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            self.cubicSplinesRGBArray = [self.lut SAMCubicSplineRGBArrayWithNormalized01XAxis];
            self.lerpRGBArray = [self.lut rgbCurveArray];
            
            self.minimumOutputValue = [self.lut minimumOutputValue];
            self.maximumOutputValue = [self.lut maximumOutputValue];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self setNeedsDisplay:YES];
            });
        });
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    
    [[NSColor whiteColor] setFill];
    NSRectFill(self.bounds);
    
    NSRect drawingRect = self.bounds;
    
    if(!self.lerpRGBArray){
        return;
    }
    
    CGContextRef context = [[NSGraphicsContext
                               currentContext] graphicsPort];

    [self drawGridInContext:context inRect:drawingRect numXDivs:clamp(self.lut.size, 0, 64) transparency:.2];
    
    if(self.interpolation == LUT1DGraphViewInterpolationLinear){
        [self drawLUT1D:self.lut inContext:context inRect:drawingRect thickness:2.0];
    }
    else if(self.interpolation == LUT1DGraphViewInterpolationCubic){
        CGContextSetRGBStrokeColor(context, 1, 0, 0, 1);
        [self drawSpline:self.cubicSplinesRGBArray[0] inContext:context inRect:drawingRect];
        CGContextSetRGBStrokeColor(context, 0, 1, 0, 1);
        [self drawSpline:self.cubicSplinesRGBArray[1] inContext:context inRect:drawingRect];
        CGContextSetRGBStrokeColor(context, 0, 0, 1, 1);
        [self drawSpline:self.cubicSplinesRGBArray[2] inContext:context inRect:drawingRect];
    }
    
    
    [self drawOverlayInContext:context inRect:drawingRect withPoint:self.mousePoint thickness:8.0];
}

- (void)drawOverlayInContext:(CGContextRef)context
                      inRect:(NSRect)rect
                   withPoint:(NSPoint)point
                   thickness:(double)thickness{
    
    
    CGFloat xOrigin = rect.origin.x;
    CGFloat yOrigin = rect.origin.y;
    CGFloat pixelWidth = rect.size.width;
    CGFloat pixelHeight = rect.size.height;
    
    double xPosition = point.x;
    
    if(outOfBounds(xPosition, xOrigin, xOrigin+pixelWidth, YES)){
        return;
    }
    
    double xPositionAsInterpolatedIndex = remap(xPosition, xOrigin, pixelWidth - xOrigin, 0, self.lut.size - 1);
    
    LUTColor *colorAtXPosition = [self.lut colorAtInterpolatedR:xPositionAsInterpolatedIndex g:xPositionAsInterpolatedIndex b:xPositionAsInterpolatedIndex];
    
    double redYPosition = remap(colorAtXPosition.red, clampUpperBound(self.minimumOutputValue, 0), clampLowerBound(self.maximumOutputValue, 1), yOrigin, yOrigin + pixelHeight);
    double greenYPosition = remap(colorAtXPosition.green, clampUpperBound(self.minimumOutputValue, 0), clampLowerBound(self.maximumOutputValue, 1), yOrigin, yOrigin + pixelHeight);
    double blueYPosition = remap(colorAtXPosition.blue, clampUpperBound(self.minimumOutputValue, 0), clampLowerBound(self.maximumOutputValue, 1), yOrigin, yOrigin + pixelHeight);
    
    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextFillEllipseInRect(context, CGRectMake(xPosition-(1.0/2.0)*thickness, redYPosition-(1.0/2.0)*thickness, thickness, thickness));
    
    CGContextSetRGBFillColor(context, 0, 1, 0, 1);
    CGContextFillEllipseInRect(context, CGRectMake(xPosition-(1.0/2.0)*thickness, greenYPosition-(1.0/2.0)*thickness, thickness, thickness));
    
    CGContextSetRGBFillColor(context, 0, 0, 1, 1);
    CGContextFillEllipseInRect(context, CGRectMake(xPosition-(1.0/2.0)*thickness, blueYPosition-(1.0/2.0)*thickness, thickness, thickness));
    
}

- (NSString *)colorStringFromCurrentMousePoint{
    CGFloat xOrigin = self.bounds.origin.x;
    CGFloat pixelWidth = self.bounds.size.width;
    
    double xPosition = self.mousePoint.x;
    double xPositionAsInterpolatedIndex = remap(xPosition, xOrigin, pixelWidth - xOrigin, 0, self.lut.size - 1);
    
    LUTColor *colorAtXPosition = [self.lut colorAtInterpolatedR:xPositionAsInterpolatedIndex g:xPositionAsInterpolatedIndex b:xPositionAsInterpolatedIndex];
    
    return [NSString stringWithFormat:@"x = %.6f %@", remap(xPositionAsInterpolatedIndex, 0, self.lut.size - 1, self.lut.inputLowerBound, self.lut.inputUpperBound), [colorAtXPosition description]];
}

- (void)drawGridInContext:(CGContextRef)context
                   inRect:(NSRect)rect
                 numXDivs:(int)numDivs
             transparency:(double)transparency{
    CGFloat xOrigin = rect.origin.x;
    CGFloat yOrigin = rect.origin.y;
    CGFloat pixelWidth = rect.size.width;
    CGFloat pixelHeight = rect.size.height;
    
    NSArray *xIndices = indicesDoubleArray(xOrigin, xOrigin + pixelWidth, numDivs);
    
    CGContextSetRGBStrokeColor(context, 1.0-transparency, 1.0-transparency, 1.0-transparency, 1);
    CGFloat strokeWidth = [[self window] backingScaleFactor] > 1 ? 0.5 : 1;
    CGContextSetLineWidth(context, strokeWidth);
    
    for (NSNumber *index in xIndices){
        double indexAsDouble = [index doubleValue];
        
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, indexAsDouble, yOrigin);
        CGContextAddLineToPoint(context, indexAsDouble, yOrigin + pixelHeight);
        CGContextStrokePath(context);
    }
    
    NSArray *yIndices = indicesDoubleArray(yOrigin, yOrigin + pixelHeight, numDivs);
    
    for (NSNumber *index in yIndices){
        double indexAsDouble = [index doubleValue];
        
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, xOrigin, indexAsDouble);
        CGContextAddLineToPoint(context, xOrigin + pixelWidth, indexAsDouble);
        CGContextStrokePath(context);
    }
    
}

- (void)drawLUT1D:(LUT1D *)lut1D inContext:(CGContextRef)context inRect:(NSRect)rect thickness:(double)thickness {
    CGFloat xOrigin = rect.origin.x;
    CGFloat yOrigin = rect.origin.y;
    CGFloat pixelWidth = rect.size.width;
    CGFloat pixelHeight = rect.size.height;
    
    //NSLog(@"Drawing in %f %f", pixelWidth, pixelHeight);
    
    CGMutablePathRef redPath = CGPathCreateMutable();
    CGMutablePathRef greenPath = CGPathCreateMutable();
    CGMutablePathRef bluePath = CGPathCreateMutable();
    
    [self.lut LUTLoopWithBlock:^(size_t r, size_t g, size_t b) {
        double indexAsXPixel = remap(r, 0, self.lut.size - 1, xOrigin, pixelWidth - xOrigin);
        
        LUTColor *color = [self.lut colorAtR:r g:g b:b];
        double redYMapped = remapNoError(color.red, clampUpperBound(self.minimumOutputValue, 0), clampLowerBound(self.maximumOutputValue, 1), yOrigin, yOrigin + pixelHeight);
        double greenYMapped = remapNoError(color.green, clampUpperBound(self.minimumOutputValue, 0), clampLowerBound(self.maximumOutputValue, 1), yOrigin, yOrigin + pixelHeight);
        double blueYMapped = remapNoError(color.blue, clampUpperBound(self.minimumOutputValue, 0), clampLowerBound(self.maximumOutputValue, 1), yOrigin, yOrigin + pixelHeight);
        
        if (r == 0) {
            CGPathMoveToPoint(redPath, nil, indexAsXPixel, redYMapped);
            CGPathMoveToPoint(greenPath, nil, indexAsXPixel, greenYMapped);
            CGPathMoveToPoint(bluePath, nil, indexAsXPixel, blueYMapped);
        } else {
            CGPathAddLineToPoint(redPath, nil, indexAsXPixel, redYMapped);
            CGPathAddLineToPoint(greenPath, nil, indexAsXPixel, greenYMapped);
            CGPathAddLineToPoint(bluePath, nil, indexAsXPixel, blueYMapped);
        }
    }];
    
    
    CGContextSetLineWidth(context, thickness);
    CGContextSetRGBStrokeColor(context, 1, 0, 0, 1);
    CGContextAddPath(context, redPath);
    CGContextStrokePath(context);
    CGContextSetRGBStrokeColor(context, 0, 1, 0, 1);
    CGContextAddPath(context, greenPath);
    CGContextStrokePath(context);
    CGContextSetRGBStrokeColor(context, 0, 0, 1, 1);
    CGContextAddPath(context, bluePath);
    CGContextStrokePath(context);
    
    CGPathRelease(redPath);
    CGPathRelease(greenPath);
    CGPathRelease(bluePath);
    
    if(self.lut.size < pixelWidth/2.0){
        CGContextSetRGBFillColor(context, 0, 0, 0, 1);
        [self.lut LUTLoopWithBlock:^(size_t r, size_t g, size_t b) {
            double indexAsXPixel = remap(r, 0, self.lut.size - 1, xOrigin, pixelWidth - xOrigin);
            
            LUTColor *color = [self.lut colorAtR:r g:g b:b];
            double redYMapped = remapNoError(color.red, clampUpperBound(self.minimumOutputValue, 0), clampLowerBound(self.maximumOutputValue, 1), yOrigin, yOrigin + pixelHeight);
            double greenYMapped = remapNoError(color.green, clampUpperBound(self.minimumOutputValue, 0), clampLowerBound(self.maximumOutputValue, 1), yOrigin, yOrigin + pixelHeight);
            double blueYMapped = remapNoError(color.blue, clampUpperBound(self.minimumOutputValue, 0), clampLowerBound(self.maximumOutputValue, 1), yOrigin, yOrigin + pixelHeight);
            CGContextFillEllipseInRect(context, CGRectMake(indexAsXPixel-(3.0/2.0)*thickness, redYMapped-(3.0/2.0)*thickness, 3.0*thickness, 3.0*thickness));
            CGContextFillEllipseInRect(context, CGRectMake(indexAsXPixel-(3.0/2.0)*thickness, greenYMapped-(3.0/2.0)*thickness, 3.0*thickness, 3.0*thickness));
            CGContextFillEllipseInRect(context, CGRectMake(indexAsXPixel-(3.0/2.0)*thickness, blueYMapped-(3.0/2.0)*thickness, 3.0*thickness, 3.0*thickness));
            
            
        }];
    }
    
}


- (void)drawSpline:(SAMCubicSpline *)spline inContext:(CGContextRef)context inRect:(NSRect)rect{
    CGFloat xOrigin = rect.origin.x;
    CGFloat yOrigin = rect.origin.y;
    CGFloat pixelWidth = rect.size.width;
    CGFloat pixelHeight = rect.size.height;
    
    //NSLog(@"Drawing in %f %f", pixelWidth, pixelHeight);
    
    CGContextSetLineWidth(context, 2.0);
    CGContextBeginPath(context);
    for (CGFloat x = 0.0f; x <= pixelWidth; x++) {
        // Get the Y value of our point
        CGFloat interpolatedY = [spline interpolate:x / (pixelWidth)];
        
        CGFloat xMapped = remap(x, 0, pixelWidth, xOrigin, xOrigin + pixelWidth);
        CGFloat yMapped = remapNoError(interpolatedY, clampUpperBound(self.minimumOutputValue, 0), clampLowerBound(self.maximumOutputValue, 1), yOrigin, yOrigin + pixelHeight);
        
        //NSLog(@"%f %f -> %f %f", x/pixelWidth, interpolatedY, x, y);
        // Add the point to the context's path
        
        if (x == xOrigin) {
            CGContextMoveToPoint(context, xMapped, yMapped);
        } else {
            CGContextAddLineToPoint(context, xMapped, yMapped);
        }
        
    }
    CGContextStrokePath(context);
    
    if([self.lut size] < pixelWidth/2.0){
        CGContextSetRGBFillColor(context, 0, 0, 0, 1);
        for (int x = 0; x < [self.lut size]; x++){
            CGFloat xMapped = remap(x, 0, [self.lut size]-1, xOrigin, xOrigin + pixelWidth);
            CGFloat yMapped = remapNoError([spline interpolate:(double)x/((double)[self.lut size]-1.0)], clampUpperBound(self.minimumOutputValue, 0), clampLowerBound(self.maximumOutputValue, 1), yOrigin, yOrigin + pixelHeight);
            CGContextFillEllipseInRect(context, CGRectMake(xMapped-3, yMapped-3, 6, 6));
        }
    }
    
}

+ (M13OrderedDictionary *)interpolationMethods{
    return M13OrderedDictionaryFromOrderedArrayWithDictionaries(@[@{@"Linear": @(LUT1DGraphViewInterpolationLinear)},
                                                                  @{@"Cubic": @(LUT1DGraphViewInterpolationCubic)}]);
}


@end
