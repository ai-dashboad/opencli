import 'dart:async';
import 'dart:io';
import 'browser_controller.dart';

/// High-level browser automation tasks
/// Provides common web automation patterns
class BrowserAutomationTasks {
  final BrowserController browser;

  BrowserAutomationTasks({required this.browser});

  /// Fill out a form
  Future<void> fillForm(Map<String, String> fieldValues) async {
    for (final entry in fieldValues.entries) {
      final field = await browser.findElement(entry.key);
      if (field != null) {
        await field.clear();
        await field.sendKeys(entry.value);
      }
    }
  }

  /// Login to website
  Future<bool> login({
    required String usernameSelector,
    required String passwordSelector,
    required String submitSelector,
    required String username,
    required String password,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      // Wait for username field
      final usernameField = await browser.waitForElement(
        usernameSelector,
        timeout: timeout,
      );
      if (usernameField == null) return false;

      // Enter username
      await usernameField.sendKeys(username);

      // Wait for password field
      final passwordField = await browser.waitForElement(
        passwordSelector,
        timeout: timeout,
      );
      if (passwordField == null) return false;

      // Enter password
      await passwordField.sendKeys(password);

      // Click submit
      final submitButton = await browser.findElement(submitSelector);
      if (submitButton == null) return false;

      await submitButton.click();

      // Wait for navigation
      await Future.delayed(Duration(seconds: 2));

      return true;
    } catch (e) {
      print('Login failed: $e');
      return false;
    }
  }

  /// Extract data from table
  Future<List<Map<String, String>>> extractTable(
    String tableSelector, {
    bool hasHeader = true,
  }) async {
    final results = <Map<String, String>>[];

    try {
      final table = await browser.findElement(tableSelector);
      if (table == null) return results;

      // Get headers if exists
      List<String>? headers;
      if (hasHeader) {
        final headerCells = await browser.findElements('$tableSelector thead th');
        headers = await Future.wait(headerCells.map((cell) => cell.getText()));
      }

      // Get rows
      final rows = await browser.findElements('$tableSelector tbody tr');

      for (final row in rows) {
        final cells = await browser.findElements('${row.id} td');
        final cellTexts = await Future.wait(cells.map((cell) => cell.getText()));

        if (headers != null && headers.length == cellTexts.length) {
          final rowData = <String, String>{};
          for (var i = 0; i < headers.length; i++) {
            rowData[headers[i]] = cellTexts[i];
          }
          results.add(rowData);
        }
      }
    } catch (e) {
      print('Table extraction failed: $e');
    }

    return results;
  }

  /// Download file
  Future<void> downloadFile({
    required String linkSelector,
    required String downloadPath,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final link = await browser.findElement(linkSelector);
    if (link == null) {
      throw Exception('Download link not found');
    }

    // Get download URL
    final url = await link.getAttribute('href');
    if (url == null) {
      throw Exception('Download URL not found');
    }

    // Click to start download
    await link.click();

    // Wait for download to complete
    await Future.delayed(Duration(seconds: 2));

    print('Download initiated from: $url');
  }

  /// Wait for page load
  Future<void> waitForPageLoad({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      final readyState = await browser.executeScript(
        'return document.readyState;',
      );

      if (readyState == 'complete') {
        return;
      }

      await Future.delayed(Duration(milliseconds: 500));
    }

    throw Exception('Page load timeout');
  }

  /// Scroll to element
  Future<void> scrollToElement(String selector) async {
    final element = await browser.findElement(selector);
    if (element == null) {
      throw Exception('Element not found: $selector');
    }

    await browser.executeScript(
      'arguments[0].scrollIntoView({behavior: "smooth", block: "center"});',
      args: [{'element-6066-11e4-a52e-4f735466cecf': element.id}],
    );

    await Future.delayed(Duration(milliseconds: 500));
  }

  /// Take full page screenshot
  Future<List<int>> takeFullPageScreenshot() async {
    // Get page height
    final height = await browser.executeScript(
      'return Math.max(document.body.scrollHeight, document.body.offsetHeight);',
    );

    // Scroll to top
    await browser.executeScript('window.scrollTo(0, 0);');
    await Future.delayed(Duration(milliseconds: 500));

    // Take screenshot
    return await browser.takeScreenshot();
  }

  /// Extract all links
  Future<List<String>> extractLinks() async {
    final links = await browser.findElements('a', by: By.tagName);
    final urls = <String>[];

    for (final link in links) {
      final href = await link.getAttribute('href');
      if (href != null && href.isNotEmpty) {
        urls.add(href);
      }
    }

    return urls;
  }

  /// Extract all images
  Future<List<String>> extractImages() async {
    final images = await browser.findElements('img', by: By.tagName);
    final urls = <String>[];

    for (final image in images) {
      final src = await image.getAttribute('src');
      if (src != null && src.isNotEmpty) {
        urls.add(src);
      }
    }

    return urls;
  }

  /// Check if element exists
  Future<bool> elementExists(String selector) async {
    final element = await browser.findElement(selector);
    return element != null;
  }

  /// Wait for element to disappear
  Future<bool> waitForElementToDisappear(
    String selector, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      final element = await browser.findElement(selector);
      if (element == null) {
        return true;
      }

      await Future.delayed(Duration(milliseconds: 500));
    }

    return false;
  }

  /// Wait for text to appear
  Future<bool> waitForText(
    String text, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      final pageSource = await browser.getPageSource();
      if (pageSource.contains(text)) {
        return true;
      }

      await Future.delayed(Duration(milliseconds: 500));
    }

    return false;
  }

  /// Execute search
  Future<List<String>> search({
    required String searchUrl,
    required String query,
    required String searchInputSelector,
    required String searchButtonSelector,
    required String resultsSelector,
  }) async {
    // Navigate to search page
    await browser.navigateTo(searchUrl);
    await waitForPageLoad();

    // Enter search query
    final searchInput = await browser.waitForElement(searchInputSelector);
    if (searchInput == null) {
      throw Exception('Search input not found');
    }

    await searchInput.sendKeys(query);

    // Click search button
    final searchButton = await browser.findElement(searchButtonSelector);
    if (searchButton == null) {
      throw Exception('Search button not found');
    }

    await searchButton.click();
    await waitForPageLoad();

    // Extract results
    final results = await browser.findElements(resultsSelector);
    final resultTexts = await Future.wait(
      results.map((r) => r.getText()),
    );

    return resultTexts;
  }

  /// Monitor page for changes
  Future<void> monitorPageChanges({
    required String selector,
    required Function(String oldValue, String newValue) onChange,
    Duration checkInterval = const Duration(seconds: 5),
    Duration duration = const Duration(minutes: 30),
  }) async {
    final endTime = DateTime.now().add(duration);
    String? previousValue;

    while (DateTime.now().isBefore(endTime)) {
      final element = await browser.findElement(selector);
      if (element != null) {
        final currentValue = await element.getText();

        if (previousValue != null && previousValue != currentValue) {
          onChange(previousValue, currentValue);
        }

        previousValue = currentValue;
      }

      await Future.delayed(checkInterval);
    }
  }

  /// Fill and submit contact form
  Future<bool> submitContactForm({
    required Map<String, String> formData,
    required String submitButtonSelector,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      // Fill form fields
      await fillForm(formData);

      // Submit form
      final submitButton = await browser.findElement(submitButtonSelector);
      if (submitButton == null) return false;

      await submitButton.click();

      // Wait for confirmation
      await Future.delayed(Duration(seconds: 2));

      return true;
    } catch (e) {
      print('Form submission failed: $e');
      return false;
    }
  }

  /// Accept cookies banner
  Future<void> acceptCookies({
    List<String> acceptSelectors = const [
      'button[id*="accept"]',
      'button[class*="accept"]',
      'button:contains("Accept")',
      '#cookie-consent-accept',
    ],
  }) async {
    for (final selector in acceptSelectors) {
      final button = await browser.findElement(selector);
      if (button != null) {
        await button.click();
        await Future.delayed(Duration(milliseconds: 500));
        return;
      }
    }
  }

  /// Navigate through pagination
  Future<List<Map<String, dynamic>>> scrapePaginatedData({
    required String nextButtonSelector,
    required Future<List<Map<String, dynamic>>> Function() extractPageData,
    int maxPages = 10,
  }) async {
    final allData = <Map<String, dynamic>>[];

    for (var page = 0; page < maxPages; page++) {
      // Extract data from current page
      final pageData = await extractPageData();
      allData.addAll(pageData);

      // Find next button
      final nextButton = await browser.findElement(nextButtonSelector);
      if (nextButton == null) break;

      // Check if button is enabled
      final isEnabled = await nextButton.isEnabled();
      if (!isEnabled) break;

      // Click next
      await nextButton.click();
      await waitForPageLoad();
    }

    return allData;
  }

  /// Handle alerts
  Future<String?> handleAlert({
    bool accept = true,
  }) async {
    try {
      final alertText = await browser.executeScript('return window.alert.toString();');

      if (accept) {
        await browser.executeScript('window.alert = function() {};');
      }

      return alertText?.toString();
    } catch (e) {
      return null;
    }
  }

  /// Check page accessibility
  Future<Map<String, dynamic>> checkAccessibility() async {
    // Get all images without alt text
    final imagesWithoutAlt = await browser.executeScript('''
      return Array.from(document.querySelectorAll('img'))
        .filter(img => !img.alt)
        .length;
    ''');

    // Get all links without text
    final linksWithoutText = await browser.executeScript('''
      return Array.from(document.querySelectorAll('a'))
        .filter(link => !link.textContent.trim())
        .length;
    ''');

    // Check for proper heading structure
    final headingStructure = await browser.executeScript('''
      return Array.from(document.querySelectorAll('h1, h2, h3, h4, h5, h6'))
        .map(h => h.tagName);
    ''');

    return {
      'images_without_alt': imagesWithoutAlt,
      'links_without_text': linksWithoutText,
      'heading_structure': headingStructure,
    };
  }
}
