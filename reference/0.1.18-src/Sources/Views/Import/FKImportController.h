#import <UIKit/UIKit.h>

/// 导入页：只读选择本地文件做 JSON 校验或 dylib/plist/zip/deb 预览，不复制、不安装、不部署。
@interface FKImportController : UITableViewController <UIDocumentPickerDelegate>
@end
