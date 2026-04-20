import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'loading_overlay.dart';

/// A thin wrapper around [Scaffold] that adds:
///
///  * Consistent padding via [horizontalPadding].
///  * An optional full-screen [LoadingOverlay] via [isLoading] / [loadingMessage].
///  * A pre-wired [FloatingActionButton] shorthand.
///
/// Use this instead of raw [Scaffold] throughout the app to keep chrome
/// consistent across screens without repeating boilerplate.
///
/// ```dart
/// AppScaffolld(
///   title: 'Recent Files',
///   isLoading: state.isLoading,
///   loadingMessage: 'Loading…',
///   body: RecentFilesList(),
/// )
/// ```
class AppScaffolld extends StatelessWidget {
  const AppScaffolld({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.actions,
    this.isLoading = false,
    this.loadingMessage,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset = true,
    this.horizontalPadding,
    this.extendBodyBehindAppBar = false,
  }) : assert(
          title == null || titleWidget == null,
          'Supply either title or titleWidget, not both.',
        );

  /// Plain-text app bar title. Mutually exclusive with [titleWidget].
  final String? title;

  /// Custom app bar title widget. Mutually exclusive with [title].
  final Widget? titleWidget;

  /// App bar trailing actions.
  final List<Widget>? actions;

  /// Main content.
  final Widget body;

  /// When true, a [LoadingOverlay] is rendered on top of [body].
  final bool isLoading;

  /// Label shown inside the [LoadingOverlay] spinner card.
  final String? loadingMessage;

  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool resizeToAvoidBottomInset;
  final bool extendBodyBehindAppBar;

  /// Wraps [body] in horizontal padding. Defaults to 0 (no extra padding).
  final double? horizontalPadding;

  @override
  Widget build(BuildContext context) {
    Widget content = horizontalPadding != null
        ? Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding!.w),
            child: body,
          )
        : body;

    content = LoadingOverlay(
      isLoading: isLoading,
      message: loadingMessage,
      child: content,
    );

    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: (title != null || titleWidget != null || actions != null)
          ? AppBar(
              title: titleWidget ?? (title != null ? Text(title!) : null),
              actions: actions,
            )
          : null,
      body: content,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}