import 'package:flutter/material.dart';

class ResponsiveUtils {
  static const double largeScreenBreakpoint = 1000;
  static const double tvBreakpoint = 1280;

  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= largeScreenBreakpoint;
  }

  static bool isTv(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= tvBreakpoint && size.height >= 700;
  }

  static double horizontalPadding(BuildContext context) {
    if (isTv(context)) return 28;
    if (isLargeScreen(context)) return 20;
    return 12;
  }

  static double maxChatContentWidth(BuildContext context) {
    if (isTv(context)) return 1240;
    if (isLargeScreen(context)) return 1040;
    return MediaQuery.sizeOf(context).width;
  }
}
