//
//  MMViewController.h
//  PowerPointThumb
//
//  Created by Adam Wulf on 5/28/14.
//  Copyright (c) 2014 Adam Wulf. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface MMThumbnailPPTController : UIViewController<WKNavigationDelegate, UIScrollViewDelegate>

-(void)generateThumbnailsForFile:(NSURL *)url;

@end
