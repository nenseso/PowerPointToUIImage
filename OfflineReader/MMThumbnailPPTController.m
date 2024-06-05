//
//  MMViewController.m
//  PowerPointThumb
//
//  Created by Adam Wulf on 5/28/14.
//  Copyright (c) 2014 Adam Wulf. All rights reserved.
//

#import "MMThumbnailPPTController.h"
#import <Masonry.h>
@implementation MMThumbnailPPTController{
    // the webview we'll use to generate thumbnails
    WKWebView *webView;
    // a uiview will help us hide the webview
    // while generation is going on
//    UIView* hidingView;

    // maximum allowed size of thumbnails
    CGFloat maxThumbnailDimension;
    
    // button and status to show what's going on
    UIButton* loadPPTButton;
    UILabel* status;
    
    // scrollview to show image output
    UIScrollView* scrollView;
    
    NSMutableArray *imageArray;
}

- (id)init{
    if(self = [super init]){
        
//        hidingView = [[UIView alloc] initWithFrame:self.view.bounds];
//        hidingView.alpha = 0;
//        [self.view addSubview:hidingView];
        
        loadPPTButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [loadPPTButton setAttributedTitle:[[NSAttributedString alloc] initWithString:@"Tap to Generate Thumbnails" attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:20]}] forState:UIControlStateNormal];
        [loadPPTButton sizeToFit];
        [loadPPTButton addTarget:self action:@selector(loadPPT:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:loadPPTButton];
        
        CGRect fr = loadPPTButton.frame;
        fr.origin.x = (self.view.bounds.size.width - loadPPTButton.bounds.size.width) / 2;
        fr.origin.y = 40;
        loadPPTButton.frame = fr;
        
        self.view.backgroundColor = [UIColor whiteColor];
        
        status = [[UILabel alloc] init];
        status.textAlignment = NSTextAlignmentCenter;
        status.text = @"";
        status.font = [UIFont systemFontOfSize:20];
        [self.view addSubview:status];

        [status mas_makeConstraints:^(MASConstraintMaker *make) {
            make.leading.equalTo(@(20));
            make.trailing.equalTo(@(-20));
            make.top.equalTo(@80);
        }];

        
        scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 120, self.view.bounds.size.width, self.view.bounds.size.height - 120)];
        [self.view addSubview:scrollView];
        
        
        maxThumbnailDimension = 300;
        
        imageArray = [NSMutableArray array];
    }
    return self;
}

// handle button press to load the default powerpoint file
-(IBAction) loadPPT:(id)sender{
    NSString* filePath = [[NSBundle mainBundle] pathForResource:@"WorstPresentationEverStandAlone" ofType:@"ppt"];
    NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
    [self generateThumbnailsForFile:fileUrl];
    
    status.text = [@"Generating thumbs for " stringByAppendingString:[filePath lastPathComponent]];
    [scrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    scrollView.contentSize = CGSizeZero;
}

// handle opening a powerpoint from any URL
- (void)generateThumbnailsForFile:(NSURL *)url {
    if(webView){
        @throw [NSException exceptionWithName:@"ThumbnailException" reason:@"Already generating thumbnails. Can only generate for 1 file at a time." userInfo:nil];
    }
    
    
    NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
    [webView removeFromSuperview];
    
    webView = [[WKWebView alloc] initWithFrame:self.view.bounds];
    webView.navigationDelegate = self;
    webView.scrollView.scrollEnabled = YES;
    webView.scrollView.delegate = self;
//    webView.scrollView.minimumZoomScale = 0;
//    webView.scrollView.maximumZoomScale = 1;
//    [hidingView addSubview:webView];
    [self.view addSubview:webView];
    
    [webView setUserInteractionEnabled:YES];
    [webView loadRequest:requestObj];
}

#pragma mark - WKWebViewDelegate
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
        [webView evaluateJavaScript:@"document.body.innerHTML" completionHandler:^(id _Nullable html, NSError * _Nullable error) {
            NSLog(@"html:\n%@", html);
        }];

    [self generateSnapshotForAllSlides];

//    [webView removeFromSuperview];
//    webView = nil;
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"error: %@", error);

}

#pragma mark - Helper Methods

- (UIImage *)screenshotWebview {
    UIGraphicsBeginImageContextWithOptions(webView.bounds.size, YES, 0.0);
    [webView drawViewHierarchyInRect:webView.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)generateSnapshotForAllSlides {
    // 获取slide数量
    NSString *js = @"document.getElementsByClassName('slide').length";

    [webView evaluateJavaScript:js completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        int slideCount = [result intValue];
        if (slideCount == 0) return;
        NSLog(@"slidecount = %d",slideCount);
        [self snapshotFromSlideIndex:0 totalSlides:slideCount currentSlideTop:0];
    }];
}

- (void)snapshotFromSlideIndex:(int)slideIndex totalSlides:(int)totalSlides currentSlideTop:(CGFloat)currentSlideTop {
    NSString *js = [NSString stringWithFormat:
                    @"(function() {"
                    "  let slideElement = document.getElementsByClassName('slide')[%d];"
                    "  let rect = slideElement.getBoundingClientRect();"
                    "  return {width: rect.width, height: rect.height};"
                    "})()", slideIndex];
    // 获取当前slide的宽和高
    [webView evaluateJavaScript:js completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error: %@", error);
            return;
        }
        CGFloat width = [result[@"width"] floatValue];
        CGFloat height = [result[@"height"] floatValue];
        CGRect bounds = webView.bounds;
        CGFloat scale = 1;
        if(width > height){
            bounds.size.width = maxThumbnailDimension;
            bounds.size.height = height / width * maxThumbnailDimension;
            scale = maxThumbnailDimension / width;
        }else{
            scale = bounds.size.width / bounds.size.height;
            bounds.size.width = (float)width / (float)height * maxThumbnailDimension;
            bounds.size.height = maxThumbnailDimension;
            scale = maxThumbnailDimension / height;
        }
        // 改变webview的大小
        webView.bounds = bounds;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ // 给0.1s刷新UI的时间
            [self snapshotForSlideAtIndex:slideIndex top:currentSlideTop  completionHandler:^(UIImage * _Nullable image) {
                if (image) {
                    [imageArray addObject:image];
                }

                if (imageArray.count == totalSlides) {
                    NSLog(@"All slide snapshots are generated.");

                    for (int slideIndex = 0; slideIndex < imageArray.count; slideIndex++) {
                        NSString* filename = [NSString stringWithFormat:@"slide%i.png", slideIndex];
                        NSArray *documentsPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                        NSString *outputImagePath = [[documentsPaths objectAtIndex:0] stringByAppendingPathComponent:filename];
                        UIImage *image = imageArray[slideIndex];
                        [UIImagePNGRepresentation(image) writeToFile:outputImagePath atomically:YES];
                        
                        CGFloat x = 34 + slideIndex % 2 * 350;
                        CGFloat y = floorf(slideIndex / 2) * 310;
                        UIImageView* imgView = [[UIImageView alloc] initWithFrame:CGRectMake(x, y, 300, 300)];
                        imgView.contentMode = UIViewContentModeScaleAspectFit;
                        imgView.image = image;
                        [scrollView addSubview:imgView];
                        int totalSlides = 14;
                        scrollView.contentSize = CGSizeMake(MAX(768,self.view.bounds.size.width), (floorf(totalSlides / 2)+1) * 300);
                        status.text = [NSString stringWithFormat:@"Generated %i thumbnails", totalSlides];
                    }
                    

                } else if (slideIndex < totalSlides - 1) {
                    NSLog(@"调用下一次,slideindex: %d", slideIndex + 1);
                    [self snapshotFromSlideIndex:slideIndex + 1 totalSlides:totalSlides currentSlideTop:currentSlideTop + bounds.size.height];
                }
            }];
        });
    }];
}


- (void)snapshotForSlideAtIndex:(int)slideIndex top:(CGFloat)top completionHandler:(void(^)( UIImage * _Nullable image))completionHandler {
//    int offset = webView.bounds.size.height * slideIndex;
    
    // 滚动到offset
    webView.scrollView.contentOffset = CGPointMake(0, top);
    // 等待webview渲染好当前页面
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 截图
        UIImage *slideThumbnailImage = [self screenshotWebview];
        completionHandler(slideThumbnailImage);
    });
}



@end
