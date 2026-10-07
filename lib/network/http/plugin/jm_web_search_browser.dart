import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/main.dart';

final _jmSearchKeepAlive = InAppWebViewKeepAlive();
Future<void> _jmSearchQueue = Future<void>.value();

/// 在保留验证会话的浏览器中加载 [uri] 指定的禁漫搜索页面。
///
/// 遇到验证页时展示浏览器供用户操作，成功后自动关闭验证窗口。
/// 返回页面 HTML 及最终地址；加载错误显示重试提示，关闭窗口时抛出取消异常。
Future<({String html, Uri uri})> loadJmSearchWebPage(Uri uri) async {
  final previous = _jmSearchQueue;
  final done = Completer<void>();
  _jmSearchQueue = done.future;
  await previous;
  try {
    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null || !context.mounted) {
      throw StateError('禁漫搜索浏览器暂时无法打开');
    }
    final route = DialogRoute<({String html, Uri uri})>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => _JmSearchBrowser(uri: uri),
    );
    final result = await Navigator.of(context, rootNavigator: true).push(route);
    // 等待旧组件移除，再让下次搜索挂载同一个原生 WebView。
    await route.completed;
    if (result == null) {
      throw StateError('已取消禁漫网站验证');
    }
    return result;
  } finally {
    done.complete();
  }
}

class _JmSearchBrowser extends StatefulWidget {
  /// 创建加载 [uri] 的浏览器窗口，返回可复用原生会话的组件。
  const _JmSearchBrowser({required this.uri});

  final Uri uri;

  /// 返回管理页面加载和验证状态的组件状态。
  @override
  State<_JmSearchBrowser> createState() => _JmSearchBrowserState();
}

class _JmSearchBrowserState extends State<_JmSearchBrowser> {
  InAppWebViewController? _controller;
  Timer? _pollTimer;
  bool _visible = false;
  bool _checking = false;
  bool _loading = true;
  bool _finished = false;
  String? _error;
  DateTime _deadline = DateTime.now().add(const Duration(seconds: 30));

  /// 初始化页面检测定时器，无参数、无返回值。
  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      unawaited(_inspectPage());
    });
  }

  /// 释放定时器并保留原生浏览器会话，无参数、无返回值。
  @override
  void dispose() {
    _finished = true;
    _pollTimer?.cancel();
    super.dispose();
  }

  /// 展示网站验证窗口并延长操作时间，无参数、无返回值。
  void _showVerification() {
    if (!mounted || _finished || _visible) {
      return;
    }
    _deadline = DateTime.now().add(const Duration(minutes: 5));
    setState(() => _visible = true);
  }

  /// 将 [message] 展示为可重试的加载错误，无返回值。
  void _showError(String message) {
    _showVerification();
    if (mounted && !_finished) {
      setState(() => _error = message);
    }
  }

  /// 检查当前浏览器文档，完成后返回搜索 HTML，验证时保持窗口可操作。
  ///
  /// 无参数，返回检查任务；页面尚未就绪时等待下一轮检查。
  Future<void> _inspectPage() async {
    if (!mounted || _finished || _checking || _error != null) {
      return;
    }
    if (DateTime.now().isAfter(_deadline)) {
      _showError('页面加载超时，请重新加载或关闭后重试');
      return;
    }
    final controller = _controller;
    if (controller == null || _loading) {
      return;
    }
    _checking = true;
    try {
      final raw = await controller.evaluateJavascript(
        source: r'''
(() => {
  const summary = document.querySelector('.well-sm');
  const result = document.querySelector('.search-pagination-total') ||
    (summary && /\d+\s*搜索結果/.test(summary.textContent));
  const challenge = !result && (!!window._cf_chl_opt ||
    !!document.querySelector('script[src*="/cdn-cgi/challenge-platform"], #challenge-running, #cf-challenge-running') ||
    /just a moment|checking your browser/i.test(document.title));
  return JSON.stringify({
    url: location.href,
    ready: document.readyState !== 'loading',
    challenge: challenge,
    html: result && !challenge ? document.documentElement.outerHTML : ''
  });
})()
''',
      );
      if (!mounted || _finished || raw is! String) {
        return;
      }
      final page = jsonDecode(raw) as Map<String, dynamic>;
      final uri = Uri.tryParse(page['url']?.toString() ?? '');
      if (uri == null || uri.path != widget.uri.path) {
        return;
      }
      final expected = widget.uri.queryParameters;
      final actual = uri.queryParameters;
      const defaults = {'page': '1', 'main_tag': '0', 'o': 'mr', 't': 'a'};
      for (final key in ['search_query', 'page', 'main_tag', 'o', 't']) {
        if ((actual[key] ?? defaults[key]) != expected[key]) {
          return;
        }
      }
      if (page['challenge'] == true) {
        _showVerification();
        return;
      }
      if (page['ready'] != true) {
        return;
      }
      final html = page['html']?.toString() ?? '';
      if (html.isEmpty) {
        _showVerification();
        return;
      }
      _finished = true;
      _pollTimer?.cancel();
      Navigator.of(context).pop((html: html, uri: uri));
    } catch (error) {
      if (mounted && !_finished) {
        _showError('读取搜索页面失败：$error');
      }
    } finally {
      _checking = false;
    }
  }

  /// 使用 [context] 构建后台加载容器及可见的网站验证窗口，返回组件。
  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !_finished) {
          _finished = true;
          _pollTimer?.cancel();
          unawaited(_controller?.stopLoading());
        }
      },
      child: Offstage(
        offstage: !_visible,
        child: Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('禁漫网站验证'),
              leading: const CloseButton(),
              actions: [
                IconButton(
                  tooltip: '重新加载',
                  icon: const Icon(Icons.refresh),
                  onPressed: () async {
                    _deadline = DateTime.now().add(const Duration(minutes: 5));
                    _loading = true;
                    setState(() => _error = null);
                    try {
                      await _controller?.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri(widget.uri.toString()),
                        ),
                      );
                    } catch (error) {
                      _showError('搜索页面加载失败：$error');
                    }
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error ?? '请完成网站验证，搜索结果加载后会自动返回'),
                ),
                Expanded(
                  child: InAppWebView(
                    keepAlive: _jmSearchKeepAlive,
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      domStorageEnabled: true,
                      cacheEnabled: true,
                      useHybridComposition: false,
                      useShouldOverrideUrlLoading: true,
                    ),
                    onWebViewCreated: (controller) async {
                      _controller = controller;
                      try {
                        await controller.loadUrl(
                          urlRequest: URLRequest(
                            url: WebUri(widget.uri.toString()),
                          ),
                        );
                      } catch (error) {
                        _showError('搜索页面加载失败：$error');
                      }
                    },
                    onLoadStart: (_, url) {
                      _loading = true;
                      if (mounted && !_finished && _error != null) {
                        setState(() => _error = null);
                      }
                    },
                    onLoadStop: (_, url) async {
                      _loading = false;
                      await _inspectPage();
                    },
                    onPageCommitVisible: (_, url) {
                      _loading = false;
                      unawaited(_inspectPage());
                    },
                    onReceivedHttpError: (_, request, response) {
                      if (request.isForMainFrame != true) {
                        return;
                      }
                      if (response.statusCode == 403 ||
                          response.statusCode == 503) {
                        _showVerification();
                      } else {
                        _showError('搜索页面请求失败：HTTP ${response.statusCode}');
                      }
                    },
                    onReceivedError: (_, request, error) {
                      if (request.isForMainFrame == true) {
                        _showError('搜索页面加载失败：${error.description}');
                      }
                    },
                    shouldOverrideUrlLoading: (_, navigation) async {
                      final uri = navigation.request.url;
                      if (navigation.isForMainFrame &&
                          uri != null &&
                          uri.toString() != 'about:blank' &&
                          ((uri.scheme != 'http' && uri.scheme != 'https') ||
                              (uri.host != widget.uri.host &&
                                  uri.host != '18comic.org'))) {
                        return NavigationActionPolicy.CANCEL;
                      }
                      return NavigationActionPolicy.ALLOW;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
