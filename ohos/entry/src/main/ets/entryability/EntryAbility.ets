import {
  FlutterAbility,
  FlutterEngine,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { common, Want } from '@kit.AbilityKit';
import { abilityAccessCtrl, Permissions, PermissionRequestResult } from '@kit.AbilityKit';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';

/**
 * 与 Android 端 MainActivity.kt 对齐的平台通道。
 *
 * Dart 侧（lib/ui/pages/edit_home_page.dart、welcome_page.dart）用
 * `org.roam.roam_flutter/photo_picker` 选壁纸 / 选文件；Android 走
 * ACTION_PICK_IMAGES，鸿蒙走 photoAccessHelper，再把结果复制进应用
 * 沙箱 filesDir —— dart:io 能直接读，且不依赖临时授权。
 */
const CHANNEL_NAME = 'org.roam.roam_flutter/photo_picker';

/**
 * 网页协议跳转 + 网页权限通道，与 Android MainActivity 的 systemChannel 对齐。
 *
 * - openExternal：`weixin://`、`alipays://`、`bilibili://`、`tel:` 这类链接
 *   交给系统，用隐式 Want（viewData）拉起对应应用，找不到就回 noHandler，
 *   Dart 侧再决定是否回退到浏览器内置页。
 * - ensurePermissions：网页 getUserMedia / geolocation 时，宿主本身必须先
 *   拿到系统授权，否则 ArkWeb 拿到的是空设备。
 * - readClipboard：鸿蒙读取剪贴板由系统弹「允许读取」确认，所以不能只在
 *   Dart 侧调 Clipboard。
 */
class RoamSystemHandler implements MethodCallHandler {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'openExternal': {
        const url = call.argument('url') as string;
        if (url === null || url === undefined || url.length === 0) {
          result.success('failed:empty url');
          return;
        }
        this.openExternal(url, result);
        break;
      }
      case 'ensurePermissions': {
        const kinds = call.argument('kinds') as Array<string>;
        this.ensurePermissions(kinds === null ? [] : kinds, result);
        break;
      }
      case 'readClipboard':
        this.readClipboard(result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private openExternal(url: string, result: MethodResult): void {
    const plain: Want = {
      action: 'ohos.want.action.viewData',
      uri: url,
    };
    const browsable: Want = {
      action: 'ohos.want.action.viewData',
      uri: url,
      entities: ['entity.system.browsable'],
    };
    // 先按最普通的 viewData 匹配（多数客户端只声明 action + uri），
    // 再补 browsable 试一次，最后用 openLink 兜底（app linking）。
    this.context
      .startAbility(plain)
      .then(() => result.success('opened'))
      .catch(() => {
        this.context
          .startAbility(browsable)
          .then(() => result.success('opened'))
          .catch(() => {
            this.context
              .openLink(url, { appLinkingOnly: false })
              .then(() => result.success('opened'))
              .catch((e: BusinessError) => {
                console.error('[Roam] openExternal failed: ' + JSON.stringify(e));
                result.success('noHandler');
              });
          });
      });
  }

  private ensurePermissions(kinds: Array<string>, result: MethodResult): void {
    const wanted: Array<Permissions> = [];
    for (const kind of kinds) {
      if (kind === 'camera') {
        wanted.push('ohos.permission.CAMERA');
      } else if (kind === 'microphone') {
        wanted.push('ohos.permission.MICROPHONE');
      } else if (kind === 'location') {
        wanted.push('ohos.permission.APPROXIMATELY_LOCATION');
        wanted.push('ohos.permission.LOCATION');
      }
    }
    if (wanted.length === 0) {
      result.success(true);
      return;
    }
    const manager = abilityAccessCtrl.createAtManager();
    manager
      .requestPermissionsFromUser(this.context, wanted)
      .then((data: PermissionRequestResult) => {
        let granted = true;
        for (const code of data.authResults) {
          if (code !== 0) {
            granted = false;
            break;
          }
        }
        result.success(granted);
      })
      .catch((err: BusinessError) => {
        console.error('[Roam] requestPermissions failed: ' + JSON.stringify(err));
        result.success(false);
      });
  }

  private readClipboard(result: MethodResult): void {
    try {
      const data = pasteboard.getSystemPasteboard().getDataSync();
      if (data === null || data === undefined) {
        result.success(null);
        return;
      }
      result.success(data.getPrimaryText());
    } catch (err) {
      // 剪贴板为空或用户拒绝读取，按「没有内容」处理。
      result.success(null);
    }
  }
}

class RoamPlatformHandler implements MethodCallHandler {
  private context: common.UIAbilityContext;
  private busy: boolean = false;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'pickImage':
        this.pickImage(result);
        break;
      case 'pickFile':
        this.pickFile(result);
        break;
      case 'openAppDetails':
        this.openAppDetails(result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private pickImage(result: MethodResult): void {
    if (this.busy) {
      result.error('BUSY', 'Another pick is in progress', null);
      return;
    }
    this.busy = true;
    const options: photoAccessHelper.PhotoSelectOptions = {
      MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: 1,
    };
    const viewPicker: photoAccessHelper.PhotoViewPicker =
      new photoAccessHelper.PhotoViewPicker();
    viewPicker
      .select(options)
      .then((res: photoAccessHelper.PhotoSelectResult) => {
        if (res.photoUris.length === 0) {
          this.busy = false;
          result.error('CANCELLED', '未选择图片', null);
          return;
        }
        const path: string | null = this.copyInto(
          res.photoUris[0],
          'wallpapers',
          'custom_wallpaper_' + Date.now().toString() + '.jpg',
        );
        this.busy = false;
        if (path === null) {
          result.error('COPY_FAILED', '图片复制失败', null);
          return;
        }
        this.pruneWallpapers(path);
        result.success(path);
      })
      .catch((err: Error) => {
        this.busy = false;
        result.error('PICK_FAILED', err.message, null);
      });
  }

  private pickFile(result: MethodResult): void {
    if (this.busy) {
      result.error('BUSY', 'Another pick is in progress', null);
      return;
    }
    this.busy = true;
    const options: picker.DocumentSelectOptions = {
      maxSelectNumber: 1,
    };
    const documentPicker: picker.DocumentViewPicker =
      new picker.DocumentViewPicker(this.context);
    documentPicker
      .select(options)
      .then((uris: Array<string>) => {
        this.busy = false;
        if (uris.length === 0) {
          result.error('CANCELLED', '未选择文件', null);
          return;
        }
        const uri: string = uris[0];
        const raw: string = uri.substring(uri.lastIndexOf('/') + 1);
        const name: string = raw.length > 0 ? raw : 'import_' + Date.now().toString();
        const path: string | null = this.copyInto(uri, 'imports', name);
        if (path === null) {
          result.error('COPY_FAILED', '文件复制失败', null);
          return;
        }
        result.success(path);
      })
      .catch((err: Error) => {
        this.busy = false;
        result.error('PICK_FAILED', err.message, null);
      });
  }

  private openAppDetails(result: MethodResult): void {
    const want: Want = {
      bundleName: 'com.huawei.hmos.settings',
      abilityName: 'com.huawei.hmos.settings.MainAbility',
      uri: 'application_info_entry',
      parameters: {
        pushParams: this.context.applicationInfo.name,
      },
    };
    this.context
      .startAbility(want)
      .then(() => result.success(true))
      .catch((err: Error) => {
        result.error('FAILED', err.message, null);
      });
  }

  /** 把 picker 返回的 uri 复制进应用沙箱，返回 Flutter 可直接读的绝对路径。 */
  private copyInto(uri: string, folder: string, fileName: string): string | null {
    let src: fileIo.File | null = null;
    try {
      const dir: string = this.context.filesDir + '/' + folder;
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir, true);
      }
      const dest: string = dir + '/' + fileName;
      src = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      fileIo.copyFileSync(src.fd, dest);
      return dest;
    } catch (err) {
      console.error('[Roam] copyInto failed: ' + JSON.stringify(err));
      return null;
    } finally {
      if (src !== null) {
        try {
          fileIo.closeSync(src);
        } catch (e) {
          // 关闭失败无需处理
        }
      }
    }
  }

  /** 只保留最新一张自定义壁纸，避免沙箱里越堆越多。 */
  private pruneWallpapers(keep: string): void {
    try {
      const dir: string = this.context.filesDir + '/wallpapers';
      const names: Array<string> = fileIo.listFileSync(dir);
      for (const name of names) {
        const full: string = dir + '/' + name;
        if (full !== keep) {
          fileIo.unlinkSync(full);
        }
      }
    } catch (err) {
      // 清理失败不影响主流程
    }
  }
}

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);
    const channel = new MethodChannel(
      flutterEngine.getDartExecutor().getBinaryMessenger(),
      CHANNEL_NAME,
    );
    channel.setMethodCallHandler(new RoamPlatformHandler(this.context));

    const systemChannel = new MethodChannel(
      flutterEngine.getDartExecutor().getBinaryMessenger(),
      'org.roam.roam_flutter/system',
    );
    systemChannel.setMethodCallHandler(new RoamSystemHandler(this.context));
  }
}
