// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' as ui show window;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'banner.dart';
import 'basic.dart';
import 'binding.dart';
import 'framework.dart';
import 'localizations.dart';
import 'media_query.dart';
import 'navigator.dart';
import 'performance_overlay.dart';
import 'semantics_debugger.dart';
import 'text.dart';
import 'title.dart';
import 'widget_inspector.dart';

export 'dart:ui' show Locale;

/// The signature of [WidgetsApp.localeResolutionCallback].
///
/// A `LocaleResolutionCallback` is responsible for computing the locale of the app's
/// [Localizations] object when the app starts and when user changes the default
/// locale for the device.
///
/// The `locale` is the device's locale when the app started, or the device
/// locale the user selected after the app was started. The `supportedLocales`
/// parameter is just the value of [WidgetsApp.supportedLocales].
typedef Locale LocaleResolutionCallback(Locale locale, Iterable<Locale> supportedLocales);

/// The signature of [WidgetsApp.onGenerateTitle].
///
/// Used to generate a value for the app's [Title.title], which the device uses
/// to identify the app for the user. The `context` includes the [WidgetsApp]'s
/// [Localizations] widget so that this method can be used to produce a
/// localized title.
///
/// This function must not return null.
typedef String GenerateAppTitle(BuildContext context);

// Delegate that fetches the default (English) strings.
class _WidgetsLocalizationsDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const _WidgetsLocalizationsDelegate();

  @override
  Future<WidgetsLocalizations> load(Locale locale) => DefaultWidgetsLocalizations.load(locale);

  @override
  bool shouldReload(_WidgetsLocalizationsDelegate old) => false;
}

/// A convenience class that wraps a number of widgets that are commonly
/// required for an application.
///
/// One of the primary roles that [WidgetsApp] provides is binding the system
/// back button to popping the [Navigator] or quitting the application.
///
/// See also: [CheckedModeBanner], [DefaultTextStyle], [MediaQuery],
/// [Localizations], [Title], [Navigator], [Overlay], [SemanticsDebugger] (the
/// widgets wrapped by this one).
///
/// The [onGenerateRoute] argument is required, and corresponds to
/// [Navigator.onGenerateRoute].
class WidgetsApp extends StatefulWidget {
  /// Creates a widget that wraps a number of widgets that are commonly
  /// required for an application.
  ///
  /// The boolean arguments, [color], [navigatorObservers], and
  /// [onGenerateRoute] must not be null.
  ///
  /// The `supportedLocales` argument must be a list of one or more elements.
  /// By default supportedLocales is `[const Locale('en', 'US')]`.
  WidgetsApp({ // can't be const because the asserts use methods on Iterable :-(
    Key key,
    @required this.onGenerateRoute,
    this.onUnknownRoute,
    this.title: '',
    this.onGenerateTitle,
    this.textStyle,
    @required this.color,
    this.navigatorObservers: const <NavigatorObserver>[],
    this.initialRoute,
    this.locale,
    this.localizationsDelegates,
    this.localeResolutionCallback,
    this.supportedLocales: const <Locale>[const Locale('en', 'US')],
    this.showPerformanceOverlay: false,
    this.checkerboardRasterCacheImages: false,
    this.checkerboardOffscreenLayers: false,
    this.showSemanticsDebugger: false,
    this.debugShowWidgetInspector: false,
    this.debugShowCheckedModeBanner: true,
    this.inspectorSelectButtonBuilder,
  }) : assert(title != null),
       assert(onGenerateRoute != null),
       assert(color != null),
       assert(navigatorObservers != null),
       assert(supportedLocales != null && supportedLocales.isNotEmpty),
       assert(showPerformanceOverlay != null),
       assert(checkerboardRasterCacheImages != null),
       assert(checkerboardOffscreenLayers != null),
       assert(showSemanticsDebugger != null),
       assert(debugShowCheckedModeBanner != null),
       assert(debugShowWidgetInspector != null),
       super(key: key);

  /// A one-line description used by the device to identify the app for the user.
  ///
  /// On Android the titles appear above the task manager's app snapshots which are
  /// displayed when the user presses the "recent apps" button. Similarly, on
  /// iOS the titles appear in the App Switcher when the user double presses the
  /// home button.
  ///
  /// To provide a localized title instead, use [onGenerateTitle].
  final String title;

  /// If non-null this callback function is called to produce the app's
  /// title string, otherwise [title] is used.
  ///
  /// The [onGenerateTitle] `context` parameter includes the [WidgetsApp]'s
  /// [Localizations] widget so that this callback can be used to produce a
  /// localized title.
  ///
  /// This callback function must not return null.
  final GenerateAppTitle onGenerateTitle;

  /// The default text style for [Text] in the application.
  final TextStyle textStyle;

  /// The primary color to use for the application in the operating system
  /// interface.
  ///
  /// For example, on Android this is the color used for the application in the
  /// application switcher.
  final Color color;

  /// The route generator callback used when the app is navigated to a
  /// named route.
  ///
  /// If this returns null when building the routes to handle the specified
  /// [initialRoute], then all the routes are discarded and
  /// [Navigator.defaultRouteName] is used instead (`/`). See [initialRoute].
  ///
  /// During normal app operation, the [onGenerateRoute] callback will only be
  /// applied to route names pushed by the application, and so should never
  /// return null.
  final RouteFactory onGenerateRoute;

  /// Called when [onGenerateRoute] fails to generate a route.
  ///
  /// This callback is typically used for error handling. For example, this
  /// callback might always generate a "not found" page that describes the route
  /// that wasn't found.
  ///
  /// Unknown routes can arise either from errors in the app or from external
  /// requests to push routes, such as from Android intents.
  final RouteFactory onUnknownRoute;

  /// The name of the first route to show.
  ///
  /// Defaults to [Window.defaultRouteName], which may be overridden by the code
  /// that launched the application.
  ///
  /// If the route contains slashes, then it is treated as a "deep link", and
  /// before this route is pushed, the routes leading to this one are pushed
  /// also. For example, if the route was `/a/b/c`, then the app would start
  /// with the three routes `/a`, `/a/b`, and `/a/b/c` loaded, in that order.
  ///
  /// If any part of this process fails to generate routes, then the
  /// [initialRoute] is ignored and [Navigator.defaultRouteName] is used instead
  /// (`/`). This can happen if the app is started with an intent that specifies
  /// a non-existent route.
  ///
  /// See also:
  ///
  ///  * [Navigator.initialRoute], which is used to implement this property.
  ///  * [Navigator.push], for pushing additional routes.
  ///  * [Navigator.pop], for removing a route from the stack.
  final String initialRoute;

  /// The initial locale for this app's [Localizations] widget.
  ///
  /// If the 'locale' is null the system's locale value is used.
  final Locale locale;

  /// The delegates for this app's [Localizations] widget.
  ///
  /// The delegates collectively define all of the localized resources
  /// for this application's [Localizations] widget.
  final Iterable<LocalizationsDelegate<dynamic>> localizationsDelegates;

  /// This callback is responsible for choosing the app's locale
  /// when the app is started, and when the user changes the
  /// device's locale.
  ///
  /// The returned value becomes the locale of this app's [Localizations]
  /// widget. The callback's `locale` parameter is the device's locale when
  /// the app started, or the device locale the user selected after the app was
  /// started. The callback's `supportedLocales` parameter is just the value
  /// [supportedLocales].
  ///
  /// If the callback is null or if it returns null then the resolved locale is:
  ///
  /// - The callback's `locale` parameter if it's equal to a supported locale.
  /// - The first supported locale with the same [Locale.languageCode] as the
  ///   callback's `locale` parameter.
  /// - The first locale in [supportedLocales].
  ///
  /// See also:
  ///
  ///  * [MaterialApp.localeResolutionCallback], which sets the callback of the
  ///    [WidgetsApp] it creates.
  final LocaleResolutionCallback localeResolutionCallback;

  /// The list of locales that this app has been localized for.
  ///
  /// By default only the American English locale is supported. Apps should
  /// configure this list to match the locales they support.
  ///
  /// This list must not null. Its default value is just
  /// `[const Locale('en', 'US')]`.
  ///
  /// The order of the list matters. By default, if the device's locale doesn't
  /// exactly match a locale in [supportedLocales] then the first locale in
  /// [supportedLocales] with a matching [Locale.languageCode] is used. If that
  /// fails then the first locale in [supportedLocales] is used. The default
  /// locale resolution algorithm can be overridden with [localeResolutionCallback].
  ///
  /// See also:
  ///
  ///  * [MaterialApp.supportedLocales], which sets the `supportedLocales`
  ///    of the [WidgetsApp] it creates.
  ///
  ///  * [localeResolutionCallback], an app callback that resolves the app's locale
  ///    when the device's locale changes.
  ///
  ///  * [localizationsDelegates], which collectively define all of the localized
  ///    resources used by this app.
  final Iterable<Locale> supportedLocales;

  /// Turns on a performance overlay.
  /// https://flutter.io/debugging/#performanceoverlay
  final bool showPerformanceOverlay;

  /// Checkerboards raster cache images.
  ///
  /// See [PerformanceOverlay.checkerboardRasterCacheImages].
  final bool checkerboardRasterCacheImages;

  /// Checkerboards layers rendered to offscreen bitmaps.
  ///
  /// See [PerformanceOverlay.checkerboardOffscreenLayers].
  final bool checkerboardOffscreenLayers;

  /// Turns on an overlay that shows the accessibility information
  /// reported by the framework.
  final bool showSemanticsDebugger;

  /// Turns on an overlay that enables inspecting the widget tree.
  ///
  /// The inspector is only available in checked mode as it depends on
  /// [RenderObject.debugDescribeChildren] which should not be called outside of
  /// checked mode.
  final bool debugShowWidgetInspector;

  /// Builds the widget the [WidgetInspector] uses to switch between view and
  /// inspect modes.
  ///
  /// This lets [MaterialApp] to use a material button to toggle the inspector
  /// select mode without requiring [WidgetInspector] to depend on the the
  /// material package.
  final InspectorSelectButtonBuilder inspectorSelectButtonBuilder;

  /// Turns on a "SLOW MODE" little banner in checked mode to indicate
  /// that the app is in checked mode. This is on by default (in
  /// checked mode), to turn it off, set the constructor argument to
  /// false. In release mode this has no effect.
  ///
  /// To get this banner in your application if you're not using
  /// WidgetsApp, include a [CheckedModeBanner] widget in your app.
  ///
  /// This banner is intended to avoid people complaining that your
  /// app is slow when it's in checked mode. In checked mode, Flutter
  /// enables a large number of expensive diagnostics to aid in
  /// development, and so performance in checked mode is not
  /// representative of what will happen in release mode.
  final bool debugShowCheckedModeBanner;

  /// The list of observers for the [Navigator] created for this app.
  final List<NavigatorObserver> navigatorObservers;

  /// If true, forces the performance overlay to be visible in all instances.
  ///
  /// Used by the `showPerformanceOverlay` observatory extension.
  static bool showPerformanceOverlayOverride = false;

  /// If true, forces the widget inspector to be visible.
  ///
  /// Used by the `debugShowWidgetInspector` debugging extension.
  ///
  /// The inspector allows you to select a location on your device or emulator
  /// and view what widgets and render objects associated with it. An outline of
  /// the selected widget and some summary information is shown on device and
  /// more detailed information is shown in the IDE or Observatory.
  static bool debugShowWidgetInspectorOverride = false;

  /// If false, prevents the debug banner from being visible.
  ///
  /// Used by the `debugAllowBanner` observatory extension.
  ///
  /// This is how `flutter run` turns off the banner when you take a screen shot
  /// with "s".
  static bool debugAllowBannerOverride = true;

  @override
  _WidgetsAppState createState() => new _WidgetsAppState();
}

class _WidgetsAppState extends State<WidgetsApp> implements WidgetsBindingObserver {
  GlobalObjectKey<NavigatorState> _navigator;
  Locale _locale;

  Locale _resolveLocale(Locale newLocale, Iterable<Locale> supportedLocales) {
    // Android devices (Java really) report 3 deprecated language codes, see
    // http://bugs.java.com/bugdatabase/view_bug.do?bug_id=4140555
    // and https://developer.android.com/reference/java/util/Locale.html
    switch (newLocale.languageCode) {
      case 'iw':
        newLocale = new Locale('he', newLocale.countryCode); // Hebrew
        break;
      case 'ji':
        newLocale = new Locale('yi', newLocale.countryCode); // Yiddish
        break;
      case 'in':
        newLocale = new Locale('id', newLocale.countryCode); // Indonesian
        break;
    }

    if (widget.localeResolutionCallback != null) {
      final Locale locale = widget.localeResolutionCallback(newLocale, widget.supportedLocales);
      if (locale != null)
        return locale;
    }

    Locale matchesLanguageCode;
    for (Locale locale in supportedLocales) {
      if (locale == newLocale)
        return newLocale;
      if (locale.languageCode == newLocale.languageCode)
        matchesLanguageCode ??= locale;
    }
    return matchesLanguageCode ?? supportedLocales.first;
  }

  @override
  void initState() {
    super.initState();
    _navigator = new GlobalObjectKey<NavigatorState>(this);
    _locale = _resolveLocale(ui.window.locale, widget.supportedLocales);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // On Android: the user has pressed the back button.
  @override
  Future<bool> didPopRoute() async {
    assert(mounted);
    final NavigatorState navigator = _navigator.currentState;
    assert(navigator != null);
    return await navigator.maybePop();
  }

  @override
  Future<bool> didPushRoute(String route) async {
    assert(mounted);
    final NavigatorState navigator = _navigator.currentState;
    assert(navigator != null);
    navigator.pushNamed(route);
    return true;
  }

  @override
  void didChangeMetrics() {
    setState(() {
      // The properties of ui.window have changed. We use them in our build
      // function, so we need setState(), but we don't cache anything locally.
    });
  }

  @override
  void didChangeLocale(Locale locale) {
    if (locale == _locale)
      return;
    final Locale newLocale = _resolveLocale(locale, widget.supportedLocales);
    if (newLocale != _locale) {
      setState(() {
        _locale = newLocale;
      });
    }
  }

  // Combine the Localizations for Widgets with the ones contributed
  // by the localizationsDelegates parameter, if any. Only the first delegate
  // of a particular LocalizationsDelegate.type is loaded so the
  // localizationsDelegate parameter can be used to override
  // _WidgetsLocalizationsDelegate.
  Iterable<LocalizationsDelegate<dynamic>> get _localizationsDelegates sync* {
    if (widget.localizationsDelegates != null)
      yield* widget.localizationsDelegates;
    yield const _WidgetsLocalizationsDelegate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { }

  @override
  void didHaveMemoryPressure() { }

  @override
  Widget build(BuildContext context) {
    Widget result = new Navigator(
      key: _navigator,
      initialRoute: widget.initialRoute ?? ui.window.defaultRouteName,
      onGenerateRoute: widget.onGenerateRoute,
      onUnknownRoute: widget.onUnknownRoute,
      observers: widget.navigatorObservers,
    );

    if (widget.textStyle != null) {
      result = new DefaultTextStyle(
        style: widget.textStyle,
        child: result,
      );
    }

    PerformanceOverlay performanceOverlay;
    // We need to push a performance overlay if any of the display or checkerboarding
    // options are set.
    if (widget.showPerformanceOverlay || WidgetsApp.showPerformanceOverlayOverride) {
      performanceOverlay = new PerformanceOverlay.allEnabled(
        checkerboardRasterCacheImages: widget.checkerboardRasterCacheImages,
        checkerboardOffscreenLayers: widget.checkerboardOffscreenLayers,
      );
    } else if (widget.checkerboardRasterCacheImages || widget.checkerboardOffscreenLayers) {
      performanceOverlay = new PerformanceOverlay(
        checkerboardRasterCacheImages: widget.checkerboardRasterCacheImages,
        checkerboardOffscreenLayers: widget.checkerboardOffscreenLayers,
      );
    }
    if (performanceOverlay != null) {
      result = new Stack(
        children: <Widget>[
          result,
          new Positioned(top: 0.0, left: 0.0, right: 0.0, child: performanceOverlay),
        ]
      );
    }

    if (widget.showSemanticsDebugger) {
      result = new SemanticsDebugger(
        child: result,
      );
    }

    assert(() {
      if (widget.debugShowWidgetInspector || WidgetsApp.debugShowWidgetInspectorOverride) {
        result = new WidgetInspector(
          child: result,
          selectButtonBuilder: widget.inspectorSelectButtonBuilder,
        );
      }
      if (widget.debugShowCheckedModeBanner && WidgetsApp.debugAllowBannerOverride) {
        result = new CheckedModeBanner(
          child: result,
        );
      }
      return true;
    }());

    return new MediaQuery(
      data: new MediaQueryData.fromWindow(ui.window),
      child: new Localizations(
        locale: widget.locale ?? _locale,
        delegates: _localizationsDelegates.toList(),
        // This Builder exists to provide a context below the Localizations widget.
        // The onGenerateCallback() can refer to Localizations via its context
        // parameter.
        child: new Builder(
          builder: (BuildContext context) {
            String title = widget.title;
            if (widget.onGenerateTitle != null) {
              title = widget.onGenerateTitle(context);
              assert(title != null, 'onGenerateTitle must return a non-null String');
            }
            return new Title(
              title: title,
              color: widget.color,
              child: result,
            );
          },
        ),
      ),
    );
  }
}
