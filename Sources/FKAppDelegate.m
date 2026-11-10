#import "FKAppDelegate.h"
#import "FKMainViewController.h"

@implementation FKAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[FKMainViewController new]];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
