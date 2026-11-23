import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  /// Factory for a generic rectangular or square block
  factory SkeletonLoader.block({
    required double width,
    required double height,
    double borderRadius = 8.0,
  }) {
    return SkeletonLoader(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }

  /// Factory for a list tile mimicking text rows
  factory SkeletonLoader.listTile() {
    return const SkeletonLoader(
      width: double.infinity,
      height: 72,
      borderRadius: 12.0,
    );
  }

  /// Factory for a generic Card
  factory SkeletonLoader.card({double height = 200}) {
    return SkeletonLoader(
      width: double.infinity,
      height: height,
      borderRadius: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
