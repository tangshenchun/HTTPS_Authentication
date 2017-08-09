//
//  NetworkManager.m
//  HttpsDemo
//
//  Created by Mac on 2017/7/20.
//  Copyright © 2017年 Mac. All rights reserved.
//

#import "NetworkManager.h"

#import <AFNetworking/AFNetworking.h>

@interface NetworkManager()

@property(nonatomic,retain)AFHTTPSessionManager * manager;
@end

@implementation NetworkManager

+(instancetype _Nullable)shareHttpManager{
    
    static dispatch_once_t onece = 0;
    static NetworkManager * httpManager = nil;
    dispatch_once(&onece, ^(void){
        httpManager = [[self alloc] init];
    });
    return httpManager;
}

-(void)get:(NSString *_Nullable)url withParameters:(id _Nullable )parameters success:(void (^_Nullable)(NSURLSessionDataTask * _Nonnull task,id _Nullable responseObject))success failure:(void (^_Nullable)(NSURLSessionDataTask * _Nonnull task,NSError * _Nonnull error))failure{
    
   
    self.manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:url]];
    self.manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    self.manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/xml",@"text/html",@"text/xml",@"text/plain",@"application/json",nil];
    
    //    设置超时时间
    [self.manager.requestSerializer willChangeValueForKey:@"timeoutInterval"];
    self.manager.requestSerializer.timeoutInterval = 30.f;
    [self.manager.requestSerializer didChangeValueForKey:@"timeoutInterval"];
    
    [self.manager setSecurityPolicy:[self customSecurityPolicy]];
    [self checkCredential:self.manager];
    

    [self.manager GET:url parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
        NSInteger code = response.statusCode;
        NSLog(@"response statusCode is %ld",(long)code);
        
        NSString *message = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        NSLog(@"message ========= %@",message);
        
        NSDictionary *responseDic = [self jsonToDictionary:message];
        success(task,responseDic);
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
        NSInteger code = response.statusCode;
        NSLog(@"response statusCode is %ld",(long)code);
        failure(task,error);
    }];
    
}
- (AFSecurityPolicy*)customSecurityPolicy {
    
    // 安全验证
    //AFSSLPinningModeCertificate: 代表客户端会将服务器端返回的证书和本地保存的证书中的所有内容，包括PublicKey和证书部分，全部进行校验；如果正确，才继续进行。
    
    NSString * cerPath = [[NSBundle mainBundle] pathForResource:@"server" ofType:@"cer"];
    NSData * cerData = [NSData dataWithContentsOfFile:cerPath];
    NSCAssert(cerData != nil, @"cerData is nil");
    
    //服务器端证书由AFSecurityPolicy 读取
    AFSecurityPolicy * securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate withPinnedCertificates:[[NSSet alloc] initWithObjects:cerData, nil]];
    
    //是否允许使用自签名证书
    securityPolicy.allowInvalidCertificates=YES;
    //是否需要验证域名
    securityPolicy.validatesDomainName=NO;
    
    return securityPolicy;
}

//校验证书
- (void)checkCredential:(AFURLSessionManager *)manager {

    //关闭缓存避免干扰测试
    self.manager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    [self.manager setSessionDidBecomeInvalidBlock:^(NSURLSession * _Nonnull session, NSError * _Nonnull error) {
        NSLog(@"setSessionDidBecomeInvalidBlock");
    }];
    
    //客服端请求验证 重写 setSessionDidReceiveAuthenticationChallengeBlock 方法
    __weak typeof(self) weakSelf = self;
    [self.manager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session, NSURLAuthenticationChallenge * _Nonnull challenge, NSURLCredential *__autoreleasing  _Nullable * _Nullable credential) {
        
        
        NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        
        __autoreleasing NSURLCredential *cdt = nil;
        
        //判断服务器要求客户端的接收认证挑战方式，如果是NSURLAuthenticationMethodServerTrust则表示去检验服务端证书是否合法，NSURLAuthenticationMethodClientCertificate则表示需要将客户端证书发送到服务端进行检验
        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
            
            NSLog(@"服务端证书认证！");
            // 基于客户端的安全策略来决定是否信任该服务器，不信任的话，也就没必要响应挑战
            if ([weakSelf.manager.securityPolicy evaluateServerTrust:challenge.protectionSpace.serverTrust forDomain:challenge.protectionSpace.host]) {
                
                 // 创建挑战证书（注：挑战方式为UseCredential和PerformDefaultHandling都需要新建挑战证书）
                cdt = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
                
                // 确定挑战的方式
                if (cdt) {
                    //证书挑战  设计policy,none，则跑到这里
                    disposition = NSURLSessionAuthChallengeUseCredential;
                } else {
                    disposition = NSURLSessionAuthChallengePerformDefaultHandling;
                }
                
            } else {
                //取消挑战 整个请求将被取消,凭证参数被忽略
                NSLog(@"不是服务器信任的证书-没有挑战的必要了");
                disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }
            
        }
        else//只有双向认证才会走这里
        {
            // client authentication
            //disposition = NSURLSessionAuthChallengePerformDefaultHandling;
            
            //p12数据中提取identity和trustobjects（可信任对象），并评估其可信度。
            SecIdentityRef identity = NULL;
            //评估证书。这里的信任对象（trustobject），包括信任策略和其他用于判断证书是否可信的信息，都已经含在了PKCS数据中。要单独评估一个证书是否可信
            SecTrustRef trust = NULL;
            NSString *p12 = [[NSBundle mainBundle] pathForResource:@"client"ofType:@"p12"];
            NSFileManager *fileManager =[NSFileManager defaultManager];
            
            if(![fileManager fileExistsAtPath:p12])
            {
                NSLog(@"客户端证书不存在！");
            }
            else
            {
                NSData *PKCS12Data = [NSData dataWithContentsOfFile:p12];
                
                if ([[weakSelf class] extractIdentity:&identity andTrust:&trust fromPKCS12Data:PKCS12Data])
                {
                    NSLog(@"加载客户端证书成功");
                    SecCertificateRef certificate = NULL;
                    SecIdentityCopyCertificate(identity, &certificate);
                    const void*certs[] = {certificate};
                    CFArrayRef certArray =CFArrayCreate(kCFAllocatorDefault, certs,1,NULL);
                    cdt =[NSURLCredential credentialWithIdentity:identity certificates:(__bridge NSArray*)certArray persistence:NSURLCredentialPersistencePermanent];
                    disposition =NSURLSessionAuthChallengeUseCredential;
                }
            }
            
        }
        
        *credential = cdt;
        
        return disposition;
    }];
}

//读取p12文件中的密码
+(BOOL)extractIdentity:(SecIdentityRef *)outIdentity andTrust:(SecTrustRef*)outTrust fromPKCS12Data:(NSData *)inPKCS12Data
{
    OSStatus securityError =errSecSuccess;
    //client certificate password
    //构造包含了密码的dictionary，用于传递给SecPKCS12Import函数。注意这里使用的是core foundation中的CFDictionaryRef，与NSDictionary完全等价
    NSDictionary *optionsDictionary = [NSDictionary dictionaryWithObject:@"123456"forKey:(id)kSecImportExportPassphrase];
    CFArrayRef items =CFArrayCreate(NULL,0, 0,NULL);
    securityError = SecPKCS12Import((CFDataRef)inPKCS12Data,(CFDictionaryRef)optionsDictionary,&items);
    if (securityError ==0) {
        CFDictionaryRef myIdentityAndTrust =CFArrayGetValueAtIndex (items, 0);
        const void *tempIdentity = NULL;
        tempIdentity = CFDictionaryGetValue (myIdentityAndTrust,kSecImportItemIdentity);
        *outIdentity = (SecIdentityRef)tempIdentity;
        const void *tempTrust = NULL;
        tempTrust = CFDictionaryGetValue (myIdentityAndTrust,kSecImportItemTrust);
        *outTrust = *(SecTrustRef*)tempTrust;
    } else {
        NSLog(@"--------证书错误------- %d",(int)securityError);
        return NO;
    }
    return YES;
}


- (NSDictionary *)jsonToDictionary:(NSString *)jsonString {
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError;
    NSDictionary *resultDic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:&jsonError];
    return resultDic;
}


@end
