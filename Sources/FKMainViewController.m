#import "FKMainViewController.h"
#import "FKScanner.h"

@interface FKMainViewController ()
@property (nonatomic, strong) FKScanReport *report;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation FKMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"FilterKit 0.0.1";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 76.0;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"导出 JSON" style:UIBarButtonItemStylePlain target:self action:@selector(exportReport)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"重新检测" style:UIBarButtonItemStylePlain target:self action:@selector(runScan)];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.navigationItem.titleView = self.spinner;
    [self runScan];
}

- (void)runScan {
    [self.spinner startAnimating];
    self.navigationItem.title = @"正在检测…";
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        FKScanReport *report = [[FKScanner new] runScan];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.report = report;
            [self.spinner stopAnimating];
            self.navigationItem.title = @"FilterKit 0.0.1";
            [self.tableView reloadData];
        });
    });
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return self.report.tests.count + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"FKResultCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.numberOfLines = 0;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (indexPath.row == 0) {
        NSUInteger passed = 0, failed = 0, unknown = 0;
        for (FKTestResult *item in self.report.tests) {
            if (item.state == FKTestStatePassed) passed++;
            else if (item.state == FKTestStateFailed) failed++;
            else unknown++;
        }
        cell.textLabel.text = @"验收概览";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"通过 %lu   失败 %lu   未确认 %lu\n只读 PoC：不会修改越狱文件或注入配置", (unsigned long)passed, (unsigned long)failed, (unsigned long)unknown];
        cell.imageView.image = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }
    FKTestResult *item = self.report.tests[indexPath.row - 1];
    NSString *symbol = item.state == FKTestStatePassed ? @"✓" : (item.state == FKTestStateFailed ? @"✕" : @"•");
    UIColor *color = item.state == FKTestStatePassed ? UIColor.systemGreenColor : (item.state == FKTestStateFailed ? UIColor.systemRedColor : UIColor.secondaryLabelColor);
    UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
    badge.text = symbol;
    badge.textColor = color;
    badge.font = [UIFont boldSystemFontOfSize:25];
    badge.textAlignment = NSTextAlignmentCenter;
    cell.accessoryView = badge;
    cell.textLabel.text = item.title;
    cell.detailTextLabel.text = item.detail;
    cell.imageView.image = nil;
    return cell;
}

- (void)exportReport {
    if (!self.report) return;
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:self.report.JSONDictionary options:NSJSONWritingPrettyPrinted error:&error];
    if (!data) {
        [self showMessage:error.localizedDescription ?: @"JSON 生成失败"];
        return;
    }
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"FilterKit-0.0.1-report.json"];
    if (![data writeToFile:path options:NSDataWritingAtomic error:&error]) {
        [self showMessage:error.localizedDescription ?: @"报告写入失败"];
        return;
    }
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) share.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:share animated:YES completion:nil];
}

- (void)showMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FilterKit" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
