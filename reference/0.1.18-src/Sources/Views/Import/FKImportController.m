#import "FKImportController.h"
#import "FKBackupManager.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface FKImportController ()
@property (nonatomic, copy) NSString *selectedName;
@property (nonatomic, copy) NSString *selectedDetail;
@end

@implementation FKImportController

- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"导入"; self.tableView.backgroundColor=UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight=64;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView;(void)section; return 2; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse=@"FKImport"; UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    if (indexPath.row==0) { cell.textLabel.text=@"选择文件"; cell.detailTextLabel.text=@"支持 .json 备份/报告校验，以及 .dylib、.plist、.zip、.deb 预览（只读）"; cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator; }
    else { cell.textLabel.text=self.selectedName ?: @"尚未选择文件"; cell.detailTextLabel.text=self.selectedDetail ?: @"0.1.15 仅进行读取、解析、预检查与校验预览，不会复制、安装、恢复或修改文件。"; cell.accessoryType=UITableViewCellAccessoryNone; }
    cell.detailTextLabel.numberOfLines=0; return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES]; if (indexPath.row!=0) return;
    UTType *dataType = [UTType typeWithIdentifier:@"public.data"];
    NSArray<UTType *> *contentTypes = dataType ? @[dataType] : @[];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:contentTypes asCopy:NO];
    picker.delegate=self; picker.allowsMultipleSelection=NO; [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    (void)controller; NSURL *url=urls.firstObject; if (!url) return;
    BOOL scoped=[url startAccessingSecurityScopedResource];
    __block NSDictionary *attrs = nil;
    __block NSError *coordinationError = nil;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    [coordinator coordinateReadingItemAtURL:url options:0 error:&coordinationError byAccessor:^(NSURL *coordinatedURL) {
        attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:coordinatedURL.path error:nil];
    }];
    NSString *ext=url.pathExtension.lowercaseString;
    self.selectedName=url.lastPathComponent;
    NSString *sizeText = attrs[NSFileSize] ? [attrs[NSFileSize] description] : @"不可读取";
    NSString *errorText = coordinationError ? [NSString stringWithFormat:@"\n访问提示：%@", coordinationError.localizedDescription] : @"";
    NSString *detail;
    if ([ext isEqualToString:@"json"]) {
        // 只读解析与校验备份/旧版报告；不恢复、不写入任何系统文件。
        NSError *vError = nil;
        FKBackupManager *validator = [[FKBackupManager alloc] initWithReport:nil];
        NSDictionary *result = [validator validateBackupAtURL:url error:&vError];
        if (result) {
            NSString *valid = [result[@"valid"] boolValue] ? @"校验通过" : @"校验未通过";
            NSString *errors = [result[@"errors"] componentsJoinedByString:@"; "];
            NSString *warnings = [result[@"warnings"] componentsJoinedByString:@"; "];
            detail = [NSString stringWithFormat:@"JSON 备份/报告\n格式：%@ · 版本：%@\n%@%@%@",
                       result[@"format"] ?: @"unknown", result[@"version"] ?: @"unknown", valid,
                       errors.length ? [NSString stringWithFormat:@"\n问题：%@", errors] : @"",
                       warnings.length ? [NSString stringWithFormat:@"\n提示：%@", warnings] : @""];
        } else {
            detail = [NSString stringWithFormat:@"JSON 校验失败：%@", vError.localizedDescription ?: @"无法解析"];
        }
    } else {
        NSString *kind=[@[@"dylib",@"plist",@"zip",@"deb"] containsObject:ext] ? ext.uppercaseString : @"未知格式";
        detail=[NSString stringWithFormat:@"类型：%@\n大小：%@ 字节\n文件：%@\n只读预览；未导入、未复制、未部署。%@",kind,sizeText,url.path,errorText];
    }
    self.selectedDetail=detail;
    if (scoped) [url stopAccessingSecurityScopedResource];
    [self.tableView reloadData];
}

@end
