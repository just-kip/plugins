// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FLTWKNavigationDelegate.h"

@implementation FLTWKNavigationDelegate {
  FlutterMethodChannel* _methodChannel;
}

- (instancetype)initWithChannel:(FlutterMethodChannel*)channel {
  self = [super init];
  if (self) {
    _methodChannel = channel;
  }
  return self;
}

- (void)webView:(WKWebView*)webView
    decidePolicyForNavigationAction:(WKNavigationAction*)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
  if (!self.hasDartNavigationDelegate) {
    decisionHandler(WKNavigationActionPolicyAllow);
    return;
  }
  NSDictionary* arguments = @{
    @"url" : navigationAction.request.URL.absoluteString,
    @"isForMainFrame" : @(navigationAction.targetFrame.isMainFrame)
  };
  [_methodChannel invokeMethod:@"navigationRequest"
                     arguments:arguments
                        result:^(id _Nullable result) {
                          if ([result isKindOfClass:[FlutterError class]]) {
                            NSLog(@"navigationRequest has unexpectedly completed with an error, "
                                  @"allowing navigation.");
                            decisionHandler(WKNavigationActionPolicyAllow);
                            return;
                          }
                          if (result == FlutterMethodNotImplemented) {
                            NSLog(@"navigationRequest was unexepectedly not implemented: %@, "
                                  @"allowing navigation.",
                                  result);
                            decisionHandler(WKNavigationActionPolicyAllow);
                            return;
                          }
                          if (![result isKindOfClass:[NSNumber class]]) {
                            NSLog(@"navigationRequest unexpectedly returned a non boolean value: "
                                  @"%@, allowing navigation.",
                                  result);
                            decisionHandler(WKNavigationActionPolicyAllow);
                            return;
                          }
                          NSNumber* typedResult = result;
                          decisionHandler([typedResult boolValue] ? WKNavigationActionPolicyAllow
                                                                  : WKNavigationActionPolicyCancel);
                        }];
}

- (void)webView:(WKWebView*)webView didFinishNavigation:(WKNavigation*)navigation {
  [_methodChannel invokeMethod:@"onPageFinished" arguments:@{@"url" : webView.URL.absoluteString}];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [_methodChannel invokeMethod:@"onPageReceiveError"
                       arguments:@{@"url" : webView.URL.absoluteString,
                                   @"code" : [NSNumber numberWithLong: error.code],
                                   @"description" : [error localizedDescription],
                                   }];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [_methodChannel invokeMethod:@"onPageReceiveError"
                       arguments:@{@"url" : error.userInfo[NSURLErrorFailingURLStringErrorKey],
                                   @"code" : [NSNumber numberWithLong: error.code],
                                   @"description" : [error localizedDescription],
                                   }];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    if ([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)navigationResponse.response;
        if (response.statusCode >= 400 && response.statusCode < 600) {
//            @throw([NSException exceptionWithName: @"e" reason:@"E" userInfo:nil]);
            [_methodChannel invokeMethod:@"onPageReceiveError"
                               arguments:@{@"url" : response.URL.absoluteString,
                                           @"code" : [NSNumber numberWithLong: response.statusCode],
                                           @"description" : [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode],
                                           }];
        }
    }
    
    decisionHandler(WKNavigationResponsePolicyAllow);
}

@end
