//
//  ViewController.m
//  HttpsDemo
//
//  Created by Tangshenchun on 2017/7/24.
//  Copyright © 2017年 tongqi. All rights reserved.
//

#import "ViewController.h"
#import "NetworkManager.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    NSString*baseUrl = @"https://121.201.15.188:11443";
    NetworkManager *httpManager = [NetworkManager shareHttpManager];
    [httpManager get:baseUrl withParameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        NSLog(@" ===== success ===== ");
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@" ===== failure ===== %@",error);
    }];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
