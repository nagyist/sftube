import 'package:flutter/material.dart';
import 'package:pstube/foundation/extensions/context/extension.dart';

extension ColorTint on Color {
  Color darken([int percent = 10]) {
    assert(
      1 <= percent && percent <= 100,
      "The percentage can't be less then 1 or greater then 100",
    );
    final f = 1 - percent / 100;
    return Color.fromARGB(
      (a * 255).toInt(),
      (r * f).toInt(),
      (g * f).toInt(),
      (b * f).toInt(),
    );
  }

  Color lighten([int percent = 10]) {
    assert(
      1 <= percent && percent <= 100,
      "The percentage can't be less then 1 or greater then 100",
    );
    final p = percent / 100;
    return Color.fromARGB(
      (a * 255).toInt(),
      (r + ((255 - r) * p)).toInt(),
      (g + ((255 - g) * p)).toInt(),
      (b + ((255 - b) * p)).toInt(),
    );
  }

  Color brighten(BuildContext ctx, [int percent = 10]) =>
      ctx.isDark ? darken(percent) : lighten(percent);

  Color brightenReverse(BuildContext ctx, [int percent = 10]) =>
      ctx.isDark ? lighten(percent) : darken(percent);
}
