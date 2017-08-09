//
//  AppDelegate.h
//  HttpsDemo
//
//  Created by Tangshenchun on 2017/7/24.
//  Copyright © 2017年 tongqi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

