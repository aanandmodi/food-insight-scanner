// lib/widgets/glass/liquid_glass_nav_bar.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../../theme/apple_motion.dart';
import '../../theme/app_design_system.dart';

/// Configuration flags for Liquid Glass rendering quality and fallbacks.
class GlassConfig {
  GlassConfig._();

  /// Whether backdrop blur (ImageFilter.blur) is enabled.
  /// If false, falls back to a high-fidelity solid semi-opaque surface.
  static bool enableBlur = true;

  /// Optional refraction lensing (gated for future native shaders).
  static bool enableRefraction = false;
}

/// A single tab item specification for [LiquidGlassNavBar].
class LiquidGlassNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const LiquidGlassNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

/// Apple-style Liquid Glass Floating Navigation Bar.
///
/// Features:
/// - Floating rounded capsule lifted above system navigation bar
/// - Real backdrop blur with edge light gradient border and depth shadows
/// - Asymmetric dual-spring sliding "glass lens" indicator that stretches like a liquid droplet
/// - Item tap spring bounce, icon pop lift, and tactile haptic feedback
/// - Drag-to-switch across the bar with velocity tracking and momentum projection
/// - Scroll-minimize support (collapses to compact icons-only capsule on scroll down)
/// - Adaptive contrast and graceful fallback for older devices
class LiquidGlassNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<LiquidGlassNavItem> items;
  final ScrollNotification? scrollNotification;
  final bool isCompact;

  const LiquidGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.scrollNotification,
    this.isCompact = false,
  });

  @override
  State<LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<LiquidGlassNavBar> with TickerProviderStateMixin {
  // Asymmetric dual springs for liquid droplet stretching:
  // Leading edge moves with high stiffness; trailing edge catches up with lower stiffness.
  late final AnimationController _leadingController;
  late final AnimationController _trailingController;
  late final AnimationController _pressController;
  late final AnimationController _compactController;

  // Track item pop animations
  late final List<AnimationController> _itemPopControllers;

  int _previousIndex = 0;
  bool _isDragging = false;
  double _dragFraction = 0.0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;

    _leadingController = AnimationController.unbounded(
      vsync: this,
      value: widget.currentIndex.toDouble(),
    );
    _trailingController = AnimationController.unbounded(
      vsync: this,
      value: widget.currentIndex.toDouble(),
    );
    _pressController = AnimationController.unbounded(
      vsync: this,
      value: 0.0,
    );
    _compactController = AnimationController(
      vsync: this,
      duration: AppleMotion.durationStandard,
      value: widget.isCompact ? 1.0 : 0.0,
    );

    _itemPopControllers = List.generate(
      widget.items.length,
      (i) => AnimationController.unbounded(
        vsync: this,
        value: i == widget.currentIndex ? 1.0 : 0.0,
      ),
    );
  }

  @override
  void didUpdateWidget(LiquidGlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animateToTab(widget.currentIndex, from: oldWidget.currentIndex);
    }
    if (oldWidget.isCompact != widget.isCompact) {
      if (widget.isCompact) {
        _compactController.forward();
      } else {
        _compactController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _leadingController.dispose();
    _trailingController.dispose();
    _pressController.dispose();
    _compactController.dispose();
    for (final c in _itemPopControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _animateToTab(int targetIndex, {int? from}) {
    final startIndex = (from ?? _previousIndex).toDouble();
    _previousIndex = targetIndex;
    final target = targetIndex.toDouble();
    final movingRight = target > startIndex;

    // Trigger icon pop on target item
    for (int i = 0; i < _itemPopControllers.length; i++) {
      if (i == targetIndex) {
        final popSim = SpringSimulation(
          AppleMotion.bouncy,
          0.0,
          1.0,
          0.0,
        );
        _itemPopControllers[i].animateWith(popSim);
      } else {
        final settleSim = SpringSimulation(
          AppleMotion.smooth,
          _itemPopControllers[i].value,
          0.0,
          0.0,
        );
        _itemPopControllers[i].animateWith(settleSim);
      }
    }

    if (MediaQuery.disableAnimationsOf(context)) {
      _leadingController.value = target;
      _trailingController.value = target;
      return;
    }

    // Droplet physics:
    // When moving right, the right edge (leading) shoots ahead with high stiffness,
    // while the left edge (trailing) follows with lower stiffness, stretching the droplet.
    // When moving left, the left edge (leading) shoots ahead first.
    const leadingSpring = SpringDescription(
      mass: 1.0,
      stiffness: 340.0,
      damping: 28.0,
    );
    const trailingSpring = SpringDescription(
      mass: 1.0,
      stiffness: 220.0,
      damping: 24.0,
    );


    if (movingRight) {
      _trailingController.animateWith(SpringSimulation(
        leadingSpring,
        _trailingController.value,
        target,
        _trailingController.velocity,
      ));
      _leadingController.animateWith(SpringSimulation(
        trailingSpring,
        _leadingController.value,
        target,
        _leadingController.velocity,
      ));
    } else {
      _leadingController.animateWith(SpringSimulation(
        leadingSpring,
        _leadingController.value,
        target,
        _leadingController.velocity,
      ));
      _trailingController.animateWith(SpringSimulation(
        trailingSpring,
        _trailingController.value,
        target,
        _trailingController.velocity,
      ));
    }
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    _isDragging = true;
    _pressController.animateWith(SpringSimulation(
      AppleMotion.snappy,
      _pressController.value,
      1.0,
      0.0,
    ));
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details, double totalWidth) {
    if (!_isDragging || widget.items.isEmpty) return;
    final itemWidth = totalWidth / widget.items.length;
    _dragFraction = (details.localPosition.dx / itemWidth).clamp(0.0, widget.items.length - 1.0);

    // Track 1:1 with finger
    _leadingController.value = _dragFraction;
    _trailingController.value = _dragFraction;
  }

  void _handleHorizontalDragEnd(DragEndDetails details, double totalWidth) {
    _isDragging = false;
    _pressController.animateWith(SpringSimulation(
      AppleMotion.smooth,
      _pressController.value,
      0.0,
      0.0,
    ));

    final itemWidth = totalWidth / widget.items.length;
    final velocityX = details.primaryVelocity ?? 0.0;
    final velocityTabs = velocityX / itemWidth;

    // Projected resting tab
    final projectedTab = AppleMotion.projectOffset(_leadingController.value, velocityTabs);
    final targetIndex = projectedTab.round().clamp(0, widget.items.length - 1);

    HapticFeedback.lightImpact();
    widget.onTap(targetIndex);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? 8 : 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            final count = widget.items.length;
            final tabWidth = barWidth / count;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _handleHorizontalDragStart,
              onHorizontalDragUpdate: (d) => _handleHorizontalDragUpdate(d, barWidth),
              onHorizontalDragEnd: (d) => _handleHorizontalDragEnd(d, barWidth),
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _leadingController,
                  _trailingController,
                  _pressController,
                  _compactController,
                ]),
                builder: (context, child) {
                  final isCompact = _compactController.value > 0.5;
                  final height = lerpDouble(66.0, 56.0, _compactController.value)!;

                  return Container(
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        // Primary soft floating depth shadow
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                          blurRadius: 28,
                          spreadRadius: -4,
                          offset: const Offset(0, 10),
                        ),
                        // Tinted secondary ground bounce shadow
                        BoxShadow(
                          color: FoodInsightColors.scannerGreen.withValues(alpha: 0.05),
                          blurRadius: 16,
                          spreadRadius: -2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: Stack(
                        children: [
                          // 1. Transparent Glass Backdrop with subtle blur
                          Positioned.fill(
                            child: GlassConfig.enableBlur
                                ? BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: isDark
                                              ? [
                                                  Colors.black.withValues(alpha: 0.35),
                                                  Colors.black.withValues(alpha: 0.20),
                                                ]
                                              : [
                                                  Colors.white.withValues(alpha: 0.45),
                                                  Colors.white.withValues(alpha: 0.25),
                                                ],
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: isDark
                                        ? const Color(0xFF1C1E22).withValues(alpha: 0.70)
                                        : Colors.white.withValues(alpha: 0.50),
                                  ),
                          ),

                          // 2. Liquid Glass Lens Droplet Selection Indicator
                          _buildLiquidLensIndicator(tabWidth, height),

                          // 3. Tab Items Layer
                          Positioned.fill(
                            child: Row(
                              children: List.generate(count, (index) {
                                return Expanded(
                                  child: _buildNavItemWidget(
                                    index: index,
                                    item: widget.items[index],
                                    isSelected: widget.currentIndex == index,
                                    isCompact: isCompact,
                                  ),
                                );
                              }),
                            ),
                          ),

                          // 4. Refraction Motion Edge Light: dynamic prismatic glow following lens
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _RefractionEdgePainter(
                                  progress: _leadingController.value,
                                  pressProgress: _pressController.value,
                                  tabCount: count,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  /// Builds the stretching liquid droplet indicator lens behind the active item.
  Widget _buildLiquidLensIndicator(double tabWidth, double height) {
    final leftVal = _leadingController.value;
    final rightVal = _trailingController.value;

    final minTab = leftVal < rightVal ? leftVal : rightVal;
    final maxTab = leftVal > rightVal ? leftVal : rightVal;

    final leftPos = (minTab * tabWidth) + 8.0;
    final lensWidth = ((maxTab - minTab + 1.0) * tabWidth) - 16.0;

    final swell = _pressController.value * 3.0;
    final lensHeight = height - 14.0 + swell;

    return Positioned(
      left: leftPos,
      top: (height - lensHeight) / 2,
      width: lensWidth.clamp(tabWidth - 16.0, tabWidth * 2.5),
      height: lensHeight,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: FoodInsightColors.scannerGreen.withValues(alpha: 0.12),
          border: Border.all(
            color: FoodInsightColors.scannerGreen.withValues(alpha: 0.28),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: FoodInsightColors.scannerGreen.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItemWidget({
    required int index,
    required LiquidGlassNavItem item,
    required bool isSelected,
    required bool isCompact,
  }) {
    final pop = _itemPopControllers[index].value.clamp(0.0, 1.25);
    final scale = 1.0 + (pop * 0.10); // Subtle 1.1x pop
    final lift = -(pop * 2.0); // 2dp lift on active pop

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = FoodInsightColors.scannerGreen;
    final inactiveColor = isDark
        ? const Color(0xFFC7C7CC)
        : const Color(0xFF3A3A3C);

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _pressController.animateWith(SpringSimulation(
            AppleMotion.snappy,
            _pressController.value,
            0.6,
            0.0,
          ));
        },
        onTapUp: (_) {
          _pressController.animateWith(SpringSimulation(
            AppleMotion.smooth,
            _pressController.value,
            0.0,
            0.0,
          ));
          widget.onTap(index);
        },
        onTapCancel: () {
          _pressController.animateWith(SpringSimulation(
            AppleMotion.smooth,
            _pressController.value,
            0.0,
            0.0,
          ));
        },
        child: Center(
          child: Transform.translate(
            offset: Offset(0, isSelected ? lift : 0),
            child: Transform.scale(
              scale: isSelected ? scale : 1.0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Inactive outline icon variant
                        Opacity(
                          opacity: (1.0 - pop).clamp(0.0, 1.0),
                          child: Icon(
                            item.icon,
                            size: 24,
                            color: inactiveColor,
                          ),
                        ),
                        // Active filled icon variant with bouncy scale morph
                        Opacity(
                          opacity: pop.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.90 + (0.10 * pop),
                            child: Icon(
                              item.activeIcon ?? item.icon,
                              size: 24,
                              color: activeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!isCompact) ...[
                    const SizedBox(height: 3),
                    AnimatedDefaultTextStyle(
                      duration: AppleMotion.durationFast,
                      style: FoodInsightTypography.caption(
                        size: 11,
                        weight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? activeColor : inactiveColor,
                      ),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter that renders the Apple-style physical refraction motion
/// along the rim of the floating glass capsule.
class _RefractionEdgePainter extends CustomPainter {
  final double progress;
  final double pressProgress;
  final int tabCount;
  final bool isDark;

  const _RefractionEdgePainter({
    required this.progress,
    required this.pressProgress,
    required this.tabCount,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1.0, size.height - 1.0),
      const Radius.circular(36),
    );

    // 1. Base glass rim highlight (top specular catch, bottom subtle shadow)
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.35),
                Colors.white.withValues(alpha: 0.08),
              ]
            : [
                Colors.white.withValues(alpha: 0.85),
                Colors.white.withValues(alpha: 0.20),
              ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(rrect, basePaint);

    // 2. Dynamic Refraction Motion Beam along the capsule edge
    // Tracks the active droplet lens position in real time
    final tabWidth = size.width / (tabCount > 0 ? tabCount : 1);
    final activeCenterX = (progress * tabWidth) + (tabWidth / 2);
    final normalizedX = (activeCenterX / size.width).clamp(0.0, 1.0);

    // Prismatic chromatic refraction beam centered at the moving lens
    final refractionPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 + (pressProgress * 0.8)
      ..shader = RadialGradient(
        center: Alignment(normalizedX * 2 - 1, -1.0),
        radius: (tabWidth * 1.5) / size.width,
        colors: [
          Colors.white,
          FoodInsightColors.scannerGreen.withValues(alpha: 0.70),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRRect(rrect, refractionPaint);

    // Subtle bottom refraction bounce
    final bottomRefractionPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = RadialGradient(
        center: Alignment(normalizedX * 2 - 1, 1.0),
        radius: (tabWidth * 1.0) / size.width,
        colors: [
          FoodInsightColors.scannerGreen.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRRect(rrect, bottomRefractionPaint);
  }

  @override
  bool shouldRepaint(covariant _RefractionEdgePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pressProgress != pressProgress ||
        oldDelegate.isDark != isDark;
  }
}
