// integration_test/e2e/helpers/widget_test_helper.dart
// Widget Test Helper for E2E Testing

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../config/e2e_test_config.dart';

/// Widget Test Helper
/// Provides reusable widget interaction methods for E2E testing
class WidgetTestHelper {
  final WidgetTester tester;
  final IntegrationTestWidgetsFlutterBinding binding;

  WidgetTestHelper(this.tester)
      : binding =
            IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ============================
  // PUMP & SETTLE
  // ============================

  /// Pump and settle with custom timeout
  Future<void> pumpAndSettle({
    Duration timeout = E2ETestConfig.pumpSettleTimeout,
  }) async {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      timeout,
    );
  }

  /// Pump with delay
  Future<void> pumpWithDelay(Duration delay) async {
    await tester.pump(delay);
  }

  /// Wait for widget to appear
  Future<bool> waitForWidget(
    Finder finder, {
    Duration timeout = E2ETestConfig.mediumTimeout,
  }) async {
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Wait for widget to disappear
  Future<bool> waitForWidgetToDisappear(
    Finder finder, {
    Duration timeout = E2ETestConfig.mediumTimeout,
  }) async {
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isEmpty) {
        return true;
      }
    }
    return false;
  }

  // ============================
  // TEXT INPUT
  // ============================

  /// Enter text in a field
  Future<void> enterText(Finder finder, String text) async {
    await tester.enterText(finder, text);
    await pumpAndSettle();
  }

  /// Enter text by key
  Future<void> enterTextByKey(Key key, String text) async {
    final finder = find.byKey(key);
    await tester.enterText(finder, text);
    await pumpAndSettle();
  }

  /// Enter text in TextField by hint
  Future<void> enterTextByHint(String hint, String text) async {
    final finder = find.widgetWithText(TextField, hint);
    if (finder.evaluate().isEmpty) {
      // Try finding by decoration hint
      final decoratedFinder = find.byWidgetPredicate((widget) {
        if (widget is TextField) {
          return widget.decoration?.hintText == hint ||
              widget.decoration?.labelText == hint;
        }
        return false;
      });
      if (decoratedFinder.evaluate().isNotEmpty) {
        await tester.enterText(decoratedFinder.first, text);
      }
    } else {
      await tester.enterText(finder.first, text);
    }
    await pumpAndSettle();
  }

  /// Clear text field
  Future<void> clearTextField(Finder finder) async {
    await tester.enterText(finder, '');
    await pumpAndSettle();
  }

  // ============================
  // TAP ACTIONS
  // ============================

  /// Tap widget (with scroll into view if needed)
  Future<void> tap(Finder finder) async {
    // Try to ensure widget is visible by scrolling if needed
    try {
      await tester.ensureVisible(finder);
      await pumpAndSettle();
    } catch (e) {
      // If ensureVisible fails, try scrolling manually
      await scrollDown();
    }

    await tester.tap(finder, warnIfMissed: false);
    await pumpAndSettle();
  }

  /// Tap by key
  Future<void> tapByKey(Key key) async {
    final finder = find.byKey(key);
    await tester.tap(finder);
    await pumpAndSettle();
  }

  /// Tap by text
  Future<void> tapByText(String text) async {
    final finder = find.text(text);
    await tester.tap(finder);
    await pumpAndSettle();
  }

  /// Tap button with text (ensures visible first)
  Future<void> tapButton(String buttonText) async {
    final elevatedFinder = find.widgetWithText(ElevatedButton, buttonText);
    if (elevatedFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(elevatedFinder.first);
      await pumpAndSettle();
      await tester.tap(elevatedFinder.first, warnIfMissed: false);
      await pumpAndSettle();
      return;
    }

    final textButtonFinder = find.widgetWithText(TextButton, buttonText);
    if (textButtonFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(textButtonFinder.first);
      await pumpAndSettle();
      await tester.tap(textButtonFinder.first, warnIfMissed: false);
      await pumpAndSettle();
      return;
    }

    final outlinedFinder = find.widgetWithText(OutlinedButton, buttonText);
    if (outlinedFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(outlinedFinder.first);
      await pumpAndSettle();
      await tester.tap(outlinedFinder.first, warnIfMissed: false);
      await pumpAndSettle();
      return;
    }

    // Fallback to text
    final textFinder = find.text(buttonText);
    if (textFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(textFinder.first);
      await pumpAndSettle();
      await tester.tap(textFinder.first, warnIfMissed: false);
      await pumpAndSettle();
    }
  }

  /// Tap icon
  Future<void> tapIcon(IconData icon) async {
    final finder = find.byIcon(icon);
    await tester.tap(finder);
    await pumpAndSettle();
  }

  /// Long press
  Future<void> longPress(Finder finder) async {
    await tester.longPress(finder);
    await pumpAndSettle();
  }

  // ============================
  // SCROLL ACTIONS
  // ============================

  /// Scroll until widget is visible
  Future<void> scrollUntilVisible(
    Finder finder, {
    Finder? scrollable,
    double delta = 100,
  }) async {
    final scrollFinder = scrollable ?? find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: scrollFinder,
    );
    await pumpAndSettle();
  }

  /// Scroll down
  Future<void> scrollDown({double delta = 300}) async {
    await tester.drag(
      find.byType(Scrollable).first,
      Offset(0, -delta),
    );
    await pumpAndSettle();
  }

  /// Scroll up
  Future<void> scrollUp({double delta = 300}) async {
    await tester.drag(
      find.byType(Scrollable).first,
      Offset(0, delta),
    );
    await pumpAndSettle();
  }

  // ============================
  // DROPDOWN & SELECTION
  // ============================

  /// Select dropdown item
  Future<void> selectDropdownItem(String dropdownHint, String itemText) async {
    // Find and tap the dropdown
    final dropdownFinder = find.byWidgetPredicate((widget) {
      if (widget is DropdownButtonFormField) {
        final decoration = widget.decoration;
        return decoration.hintText == dropdownHint ||
            decoration.labelText == dropdownHint;
      }
      return false;
    });

    if (dropdownFinder.evaluate().isNotEmpty) {
      await tester.tap(dropdownFinder.first);
      await pumpAndSettle();

      // Select the item
      final itemFinder = find.text(itemText);
      if (itemFinder.evaluate().isNotEmpty) {
        await tester.tap(itemFinder.last);
        await pumpAndSettle();
      }
    }
  }

  /// Toggle switch
  Future<void> toggleSwitch(Finder finder) async {
    await tester.tap(finder);
    await pumpAndSettle();
  }

  // ============================
  // VERIFICATION
  // ============================

  /// Check if widget exists
  bool widgetExists(Finder finder) {
    return finder.evaluate().isNotEmpty;
  }

  /// Check if text is visible
  bool textIsVisible(String text) {
    return find.text(text).evaluate().isNotEmpty;
  }

  /// Check if widget is enabled
  bool isEnabled(Finder finder) {
    final widget = tester.widget(finder);
    if (widget is ElevatedButton) return widget.onPressed != null;
    if (widget is TextButton) return widget.onPressed != null;
    if (widget is OutlinedButton) return widget.onPressed != null;
    if (widget is IconButton) return widget.onPressed != null;
    return true;
  }

  /// Get text from widget
  String? getTextFromWidget(Finder finder) {
    try {
      final widget = tester.widget(finder);
      if (widget is Text) return widget.data;
      if (widget is TextField) return widget.controller?.text;
      if (widget is TextFormField) return widget.controller?.text;
      return null;
    } catch (e) {
      return null;
    }
  }

  // ============================
  // NAVIGATION
  // ============================

  /// Navigate back
  Future<void> navigateBack() async {
    final backButton = find.byTooltip('Back');
    if (backButton.evaluate().isNotEmpty) {
      await tester.tap(backButton);
      await pumpAndSettle();
      return;
    }

    final arrowBack = find.byIcon(Icons.arrow_back);
    if (arrowBack.evaluate().isNotEmpty) {
      await tester.tap(arrowBack);
      await pumpAndSettle();
      return;
    }

    final arrowBackIos = find.byIcon(Icons.arrow_back_ios);
    if (arrowBackIos.evaluate().isNotEmpty) {
      await tester.tap(arrowBackIos);
      await pumpAndSettle();
    }
  }

  /// Tap bottom navigation item
  Future<void> tapBottomNavItem(int index) async {
    final bottomNav = find.byType(BottomNavigationBar);
    if (bottomNav.evaluate().isNotEmpty) {
      final navWidget = tester.widget<BottomNavigationBar>(bottomNav.first);
      final item = navWidget.items[index];
      // Find the icon widget directly
      if (item.icon is Icon) {
        final icon = item.icon as Icon;
        final itemFinder = find.byIcon(icon.icon!);
        if (itemFinder.evaluate().isNotEmpty) {
          await tester.tap(itemFinder.first);
          await pumpAndSettle();
        }
      }
    }
  }

  // ============================
  // DIALOGS & SHEETS
  // ============================

  /// Dismiss dialog
  Future<void> dismissDialog() async {
    // Try tapping outside
    await tester.tapAt(const Offset(10, 10));
    await pumpAndSettle();
  }

  /// Confirm dialog (tap OK/Confirm/Yes)
  Future<void> confirmDialog() async {
    final confirmButtons = ['OK', 'Confirm', 'Yes', 'Submit', 'Save'];
    for (final text in confirmButtons) {
      final finder = find.text(text);
      if (finder.evaluate().isNotEmpty) {
        await tester.tap(finder);
        await pumpAndSettle();
        return;
      }
    }
  }

  /// Cancel dialog
  Future<void> cancelDialog() async {
    final cancelButtons = ['Cancel', 'No', 'Close', 'Dismiss'];
    for (final text in cancelButtons) {
      final finder = find.text(text);
      if (finder.evaluate().isNotEmpty) {
        await tester.tap(finder);
        await pumpAndSettle();
        return;
      }
    }
  }

  // ============================
  // SCREENSHOT
  // ============================

  /// Take screenshot
  Future<String?> takeScreenshot(String name) async {
    try {
      await E2ETestConfig.ensureDirectories();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${name}_$timestamp.png';
      final filePath = '${E2ETestConfig.screenshotDirectory}/$fileName';

      // Use binding to take screenshot
      final List<int> bytes = await binding.takeScreenshot(name);

      if (bytes.isNotEmpty) {
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        return filePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Take screenshot on failure
  Future<String?> takeFailureScreenshot(String testName) async {
    final safeName = testName.replaceAll(RegExp(r'[^\w\s-]'), '_');
    return await takeScreenshot('FAILURE_$safeName');
  }
}

/// Test result wrapper for running individual tests
class E2ETestRunner {
  final WidgetTestHelper helper;
  final E2ETestContext context;

  E2ETestRunner(this.helper, this.context);

  /// Run a test with automatic timing and error handling
  Future<E2ETestResult> runTest({
    required String name,
    required String category,
    required Future<void> Function() testFunction,
  }) async {
    final startTime = DateTime.now();
    String? errorMessage;
    String? stackTrace;
    String? screenshotPath;
    bool passed = true;

    try {
      await testFunction();
    } catch (e, st) {
      passed = false;
      errorMessage = e.toString();
      stackTrace = st.toString();

      // Take screenshot on failure
      if (E2ETestConfig.captureScreenshotsOnFailure) {
        screenshotPath = await helper.takeFailureScreenshot(name);
      }
    }

    final duration = DateTime.now().difference(startTime);
    final result = E2ETestResult(
      testName: name,
      category: category,
      passed: passed,
      duration: duration,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      screenshotPath: screenshotPath,
    );

    context.addResult(result);
    return result;
  }
}
