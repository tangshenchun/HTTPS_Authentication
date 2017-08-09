//
//  NetworkManager.h
//  HttpsDemo
//
//  Created by Mac on 2017/7/20.
//  Copyright © 2017年 Mac. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NetworkManager : NSObject

+(instancetype _Nullable)shareHttpManager;

-(void)get:(NSString *_Nullable)url withParameters:(id _Nullable )parameters success:(void (^_Nullable)(NSURLSessionDataTask * _Nonnull task,id _Nullable responseObject))success failure:(void (^_Nullable)(NSURLSessionDataTask * _Nonnull task,NSError * _Nonnull error))failure;

@end
