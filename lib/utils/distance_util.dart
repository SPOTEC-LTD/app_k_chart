import 'dart:math' as math;

import 'package:flutter/material.dart';

class DistanceUtil {
  static double distanceToPoint(Offset p1, Offset p2) {
    var x1 = p1.dx;
    var y1 = p1.dy;
    var x2 = p2.dx;
    var y2 = p2.dy;
    return math.sqrt(math.pow(x1 - x2, 2) + math.pow(y1 - y2, 2));
  }

  // 点到线段的距离
  static double distanceToSegment(
      Offset point, Offset linePoint1, Offset linePoint2) {
    var x = point.dx;
    var y = point.dy;
    var x1 = linePoint1.dx;
    var y1 = linePoint1.dy;
    var x2 = linePoint2.dx;
    var y2 = linePoint2.dy;

    var A = x - x1;
    var B = y - y1;
    var C = x2 - x1;
    var D = y2 - y1;

    var dot = A * C + B * D;
    var lenSq = C * C + D * D;
    var param = -1.0;
    if (lenSq != 0) {
      param = dot / lenSq;
    }

    var xx, yy;

    if (param < 0) {
      xx = x1;
      yy = y1;
    } else if (param > 1) {
      xx = x2;
      yy = y2;
    } else {
      xx = x1 + param * C;
      yy = y1 + param * D;
    }

    var dx = x - xx;
    var dy = y - yy;
    return math.sqrt(dx * dx + dy * dy);
  }
}
