import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Controls web browser automation using WebDriver protocol
/// Supports Chrome, Firefox, Safari via WebDriver
class BrowserController {
  final String webDriverUrl;
  String? sessionId;
  final BrowserType browserType;

  BrowserController({
    this.webDriverUrl = 'http://localhost:9515',
    this.browserType = BrowserType.chrome,
  });

  /// Start a browser session
  Future<void> startSession({
    bool headless = false,
    Map<String, dynamic>? options,
  }) async {
    final capabilities =
        _buildCapabilities(headless: headless, options: options);

    final response = await http.post(
      Uri.parse('$webDriverUrl/session'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'capabilities': capabilities}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to start browser session: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    sessionId = data['value']['sessionId'] as String;

    print('Browser session started: $sessionId');
  }

  /// Stop the browser session
  Future<void> stopSession() async {
    if (sessionId == null) return;

    await http.delete(
      Uri.parse('$webDriverUrl/session/$sessionId'),
    );

    print('Browser session stopped: $sessionId');
    sessionId = null;
  }

  /// Navigate to URL
  Future<void> navigateTo(String url) async {
    _ensureSession();

    await http.post(
      Uri.parse('$webDriverUrl/session/$sessionId/url'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url}),
    );

    print('Navigated to: $url');
  }

  /// Get current URL
  Future<String> getCurrentUrl() async {
    _ensureSession();

    final response = await http.get(
      Uri.parse('$webDriverUrl/session/$sessionId/url'),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['value'] as String;
  }

  /// Get page title
  Future<String> getTitle() async {
    _ensureSession();

    final response = await http.get(
      Uri.parse('$webDriverUrl/session/$sessionId/title'),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['value'] as String;
  }

  /// Find element by selector
  Future<WebElement?> findElement(String selector, {By by = By.css}) async {
    _ensureSession();

    try {
      final response = await http.post(
        Uri.parse('$webDriverUrl/session/$sessionId/element'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'using': by.value,
          'value': selector,
        }),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final elementId =
          data['value']['element-6066-11e4-a52e-4f735466cecf'] as String;

      return WebElement(
        id: elementId,
        sessionId: sessionId!,
        webDriverUrl: webDriverUrl,
      );
    } catch (e) {
      return null;
    }
  }

  /// Find multiple elements by selector
  Future<List<WebElement>> findElements(String selector,
      {By by = By.css}) async {
    _ensureSession();

    try {
      final response = await http.post(
        Uri.parse('$webDriverUrl/session/$sessionId/elements'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'using': by.value,
          'value': selector,
        }),
      );

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = data['value'] as List<dynamic>;

      return elements.map((e) {
        final elementId = e['element-6066-11e4-a52e-4f735466cecf'] as String;
        return WebElement(
          id: elementId,
          sessionId: sessionId!,
          webDriverUrl: webDriverUrl,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Execute JavaScript
  Future<dynamic> executeScript(String script, {List<dynamic>? args}) async {
    _ensureSession();

    final response = await http.post(
      Uri.parse('$webDriverUrl/session/$sessionId/execute/sync'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'script': script,
        'args': args ?? [],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to execute script: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['value'];
  }

  /// Take screenshot
  Future<List<int>> takeScreenshot() async {
    _ensureSession();

    final response = await http.get(
      Uri.parse('$webDriverUrl/session/$sessionId/screenshot'),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final base64Image = data['value'] as String;

    return base64Decode(base64Image);
  }

  /// Get page source
  Future<String> getPageSource() async {
    _ensureSession();

    final response = await http.get(
      Uri.parse('$webDriverUrl/session/$sessionId/source'),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['value'] as String;
  }

  /// Go back
  Future<void> goBack() async {
    _ensureSession();

    await http.post(
      Uri.parse('$webDriverUrl/session/$sessionId/back'),
    );
  }

  /// Go forward
  Future<void> goForward() async {
    _ensureSession();

    await http.post(
      Uri.parse('$webDriverUrl/session/$sessionId/forward'),
    );
  }

  /// Refresh page
  Future<void> refresh() async {
    _ensureSession();

    await http.post(
      Uri.parse('$webDriverUrl/session/$sessionId/refresh'),
    );
  }

  /// Get cookies
  Future<List<Cookie>> getCookies() async {
    _ensureSession();

    final response = await http.get(
      Uri.parse('$webDriverUrl/session/$sessionId/cookie'),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final cookies = data['value'] as List<dynamic>;

    return cookies
        .map((c) => Cookie.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// Add cookie
  Future<void> addCookie(Cookie cookie) async {
    _ensureSession();

    await http.post(
      Uri.parse('$webDriverUrl/session/$sessionId/cookie'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'cookie': cookie.toJson()}),
    );
  }

  /// Delete all cookies
  Future<void> deleteAllCookies() async {
    _ensureSession();

    await http.delete(
      Uri.parse('$webDriverUrl/session/$sessionId/cookie'),
    );
  }

  /// Switch to frame
  Future<void> switchToFrame(int frameIndex) async {
    _ensureSession();

    await http.post(
      Uri.parse('$webDriverUrl/session/$sessionId/frame'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': frameIndex}),
    );
  }

  /// Switch to default content
  Future<void> switchToDefaultContent() async {
    _ensureSession();

    await http.post(
      Uri.parse('$webDriverUrl/session/$sessionId/frame'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': null}),
    );
  }

  /// Wait for element
  Future<WebElement?> waitForElement(
    String selector, {
    By by = By.css,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      final element = await findElement(selector, by: by);
      if (element != null) {
        return element;
      }

      await Future.delayed(Duration(milliseconds: 500));
    }

    return null;
  }

  /// Build capabilities for browser
  Map<String, dynamic> _buildCapabilities({
    bool headless = false,
    Map<String, dynamic>? options,
  }) {
    final caps = <String, dynamic>{};

    switch (browserType) {
      case BrowserType.chrome:
        final chromeOptions = <String, dynamic>{
          'args': [
            if (headless) '--headless',
            '--no-sandbox',
            '--disable-dev-shm-usage',
          ],
        };
        if (options != null) {
          chromeOptions.addAll(options);
        }
        caps['goog:chromeOptions'] = chromeOptions;
        break;

      case BrowserType.firefox:
        final firefoxOptions = <String, dynamic>{
          'args': [
            if (headless) '-headless',
          ],
        };
        if (options != null) {
          firefoxOptions.addAll(options);
        }
        caps['moz:firefoxOptions'] = firefoxOptions;
        break;

      case BrowserType.safari:
        // Safari doesn't support headless mode
        if (options != null) {
          caps.addAll(options);
        }
        break;
    }

    return {
      'alwaysMatch': caps,
    };
  }

  /// Ensure session is active
  void _ensureSession() {
    if (sessionId == null) {
      throw Exception('Browser session not started');
    }
  }
}

/// Web element
class WebElement {
  final String id;
  final String sessionId;
  final String webDriverUrl;

  WebElement({
    required this.id,
    required this.sessionId,
    required this.webDriverUrl,
  });

  /// Click element
  Future<void> click() async {
    await http.post(
      Uri.parse('$webDriverUrl/session/$sessionId/element/$id/click'),
    );
  }

  /// Send keys to element
  Future<void> sendKeys(String text) async {
    await http.post(
      Uri.parse('$webDriverUrl/session/$sessionId/element/$id/value'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );
  }

  /// Clear element
  Future<void> clear() async {
    await http.post(
      Uri.parse('$webDriverUrl/session/$sessionId/element/$id/clear'),
    );
  }

  /// Get element text
  Future<String> getText() async {
    final response = await http.get(
      Uri.parse('$webDriverUrl/session/$sessionId/element/$id/text'),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['value'] as String;
  }

  /// Get element attribute
  Future<String?> getAttribute(String name) async {
    final response = await http.get(
      Uri.parse('$webDriverUrl/session/$sessionId/element/$id/attribute/$name'),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['value'] as String?;
  }

  /// Get element property
  Future<dynamic> getProperty(String name) async {
    final response = await http.get(
      Uri.parse('$webDriverUrl/session/$sessionId/element/$id/property/$name'),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['value'];
  }

  /// Is element displayed
  Future<bool> isDisplayed() async {
    final response = await http.get(
      Uri.parse('$webDriverUrl/session/$sessionId/element/$id/displayed'),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['value'] as bool;
  }

  /// Is element enabled
  Future<bool> isEnabled() async {
    final response = await http.get(
      Uri.parse('$webDriverUrl/session/$sessionId/element/$id/enabled'),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['value'] as bool;
  }

  /// Is element selected
  Future<bool> isSelected() async {
    final response = await http.get(
      Uri.parse('$webDriverUrl/session/$sessionId/element/$id/selected'),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['value'] as bool;
  }
}

/// Browser cookie
class Cookie {
  final String name;
  final String value;
  final String? domain;
  final String? path;
  final bool? secure;
  final bool? httpOnly;
  final int? expiry;

  Cookie({
    required this.name,
    required this.value,
    this.domain,
    this.path,
    this.secure,
    this.httpOnly,
    this.expiry,
  });

  factory Cookie.fromJson(Map<String, dynamic> json) {
    return Cookie(
      name: json['name'] as String,
      value: json['value'] as String,
      domain: json['domain'] as String?,
      path: json['path'] as String?,
      secure: json['secure'] as bool?,
      httpOnly: json['httpOnly'] as bool?,
      expiry: json['expiry'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      if (domain != null) 'domain': domain,
      if (path != null) 'path': path,
      if (secure != null) 'secure': secure,
      if (httpOnly != null) 'httpOnly': httpOnly,
      if (expiry != null) 'expiry': expiry,
    };
  }
}

/// Browser type
enum BrowserType { chrome, firefox, safari }

/// Element locator strategy
enum By {
  css('css selector'),
  xpath('xpath'),
  id('id'),
  name('name'),
  className('class name'),
  tagName('tag name'),
  linkText('link text'),
  partialLinkText('partial link text');

  final String value;
  const By(this.value);
}
