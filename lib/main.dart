import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

const String desktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

// Ajuste de layout via viewport, não via CSS de classes ofuscadas.
// O WhatsApp muda os nomes de classe a cada atualização; mexer só no
// viewport é mais estável e não quebra quando eles atualizam o site.
const String layoutFixJs = '''
(function() {
  function applyViewport() {
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      document.head.appendChild(meta);
    }
    meta.content = 'width=1000, initial-scale=0.42, minimum-scale=0.3, maximum-scale=1, user-scalable=yes';
  }
  applyViewport();
  var observer = new MutationObserver(applyViewport);
  observer.observe(document.head, { childList: true, subtree: true });
})();
''';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(WppTaskHandler());
}

// Handler mínimo exigido pelo flutter_foreground_task para manter
// o processo vivo em segundo plano (impede o Android de matar o app).
class WppTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  runApp(const WppWrapperApp());
}

class WppWrapperApp extends StatelessWidget {
  const WppWrapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF25D366),
        useMaterial3: true,
      ),
      home: const WppHomePage(),
    );
  }
}

class WppHomePage extends StatefulWidget {
  const WppHomePage({super.key});

  @override
  State<WppHomePage> createState() => _WppHomePageState();
}

class _WppHomePageState extends State<WppHomePage>
    with WidgetsBindingObserver {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _loadFailed = false;

  static const _wppUrl = 'https://web.whatsapp.com';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
    _initForegroundTask();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
      Permission.photos,
      Permission.notification,
    ].request();
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'wpp_wrapper_channel',
        channelName: 'WhatsApp em execução',
        channelDescription: 'Mantendo a sessão conectada em segundo plano',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    FlutterForegroundTask.startService(
      notificationTitle: 'WhatsApp conectado',
      notificationText: 'Mantendo sua sessão ativa',
      callback: startCallback,
    );
  }

  // Pausa/retoma o WebView conforme o app vai pro background e volta.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _controller!.pause();
        break;
      case AppLifecycleState.resumed:
        _controller!.resume();
        _controller!.getUrl().then((url) {
          if (url == null) {
            _controller!.loadUrl(
              urlRequest: URLRequest(url: WebUri(_wppUrl)),
            );
          }
        });
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.stopService();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loadFailed = false);
    await _controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_wppUrl)),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da sessão?'),
        content: const Text(
          'Isso vai apagar os dados salvos (cookies e sessão) e você vai '
          'precisar escanear o QR code de novo no próximo uso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _controller?.evaluateJavascript(
        source: 'window.localStorage.clear(); window.sessionStorage.clear();',
      );
      final cookieManager = CookieManager.instance();
      await cookieManager.deleteAllCookies();
      await WebStorageManager.instance().deleteAllData();
      await _reload();
    }
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: const Color(0xFF111B21),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: Colors.white54, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Não foi possível carregar.\nVerifique sua conexão.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _reload,
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111B21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF202C33),
        title: const Text('WhatsApp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: _reload,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair da sessão',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialSettings: InAppWebViewSettings(
                userAgent: desktopUserAgent,
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                thirdPartyCookiesEnabled: true,
                cacheEnabled: true,
                allowFileAccess: true,
                allowContentAccess: true,
                mediaPlaybackRequiresUserGesture: false,
                useHybridComposition: true,
                supportZoom: false,
                builtInZoomControls: false,
              ),
              initialUrlRequest: URLRequest(url: WebUri(_wppUrl)),
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              onProgressChanged: (controller, progress) {
                setState(() => _progress = progress / 100);
              },
              onLoadStop: (controller, url) async {
                await controller.evaluateJavascript(source: layoutFixJs);
                setState(() => _loadFailed = false);
              },
              onReceivedError: (controller, request, error) {
                if (request.isForMainFrame ?? true) {
                  setState(() => _loadFailed = true);
                }
              },
              // Sem isso, o clique no clipe de anexo (foto/documento/áudio)
              // do WhatsApp Web não abre nada.
              onShowFileChooser: (controller, params) async {
                try {
                  final allowMultiple =
                      params.mode == FileChooserMode.OPEN_MULTIPLE;
                  final result = await FilePicker.platform.pickFiles(
                    allowMultiple: allowMultiple,
                    type: FileType.any,
                  );
                  if (result == null || result.files.isEmpty) {
                    return [];
                  }
                  return result.files
                      .where((f) => f.path != null)
                      .map((f) => f.path!)
                      .toList();
                } catch (_) {
                  return [];
                }
              },
              androidOnPermissionRequest: (controller, origin, resources) async {
                return PermissionRequestResponse(
                  resources: resources,
                  action: PermissionRequestResponseAction.GRANT,
                );
              },
              onPermissionRequest: (controller, request) async {
                return PermissionResponse(
                  resources: request.resources,
                  action: PermissionResponseAction.GRANT,
                );
              },
            ),
            if (_progress < 1 && !_loadFailed)
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.transparent,
                color: const Color(0xFF25D366),
              ),
            if (_loadFailed) _buildErrorOverlay(),
          ],
        ),
      ),
    );
  }
}
