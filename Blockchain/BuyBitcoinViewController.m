//
//  BuyBitcoinViewController.m
//  Blockchain
//
//  Created by kevinwu on 1/27/17.
//  Copyright © 2017 Blockchain Luxembourg S.A. All rights reserved.
//

#import "BuyBitcoinViewController.h"
#import <WebKit/WebKit.h>
#import "NSString+NSString_EscapeQuotes.h"


@interface BuyBitcoinViewController () <WKNavigationDelegate>
@property (nonatomic) WKWebView *webView;

@property (nonatomic) NSString *guid;
@property (nonatomic) NSString *sharedKey;
@property (nonatomic) NSString *password;
@end

@implementation BuyBitcoinViewController

- (id)initWithGuid:(NSString *)guid sharedKey:(NSString *)sharedKey password:(NSString *)password
{
    if (self = [super init]) {
        self.guid = guid;
        self.sharedKey = sharedKey;
        self.password = password;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.webView = [[WKWebView alloc] initWithFrame:self.view.frame];
    self.webView.navigationDelegate = self;
    self.view = self.webView;
    
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://10.0.0.175:8080/wallet/#/login"]];
    [self.webView loadRequest:request];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [self performSelector:@selector(login) withObject:nil afterDelay:2];
}

- (void)login
{
    NSString *function = [NSString stringWithFormat:@"activateMobileBuy(\"%@\", \"%@\", \"%@\")", [self.guid escapeStringForJS], [self.sharedKey escapeStringForJS], [self.password escapeStringForJS]];
    [self.webView evaluateJavaScript:function completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        DLog(@"completionhandler");
    }];
}

@end
