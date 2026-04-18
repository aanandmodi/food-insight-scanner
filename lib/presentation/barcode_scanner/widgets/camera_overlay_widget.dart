import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class CameraOverlayWidget extends StatefulWidget {
  final VoidCallback? onClose;
  final VoidCallback? onFlashToggle;
  final bool isFlashOn;
  final bool isScanning;

  const CameraOverlayWidget({
    super.key,
    this.onClose,
    this.onFlashToggle,
    this.isFlashOn = false,
    this.isScanning = false,
  });

  @override
  State<CameraOverlayWidget> createState() => _CameraOverlayWidgetState();
}

class _CameraOverlayWidgetState extends State<CameraOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (widget.isScanning) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CameraOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !oldWidget.isScanning) {
      _animationController.repeat(reverse: true);
    } else if (!widget.isScanning && oldWidget.isScanning) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          // Semi-transparent overlay
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withValues(alpha: 0.6),
          ),

          // Scanning area cutout
          Center(
            child: Container(
              width: 70.w,
              height: 35.h,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.lightTheme.colorScheme.primary,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          ),

          // Animated scanning reticle
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.isScanning ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 70.w,
                    height: 35.h,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: widget.isScanning
                            ? AppTheme.lightTheme.colorScheme.primary
                            : AppTheme.lightTheme.colorScheme.primary
                                .withValues(alpha: 0.5),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        // Corner indicators
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: AppTheme.lightTheme.colorScheme.primary,
                                  width: 4,
                                ),
                                left: BorderSide(
                                  color: AppTheme.lightTheme.colorScheme.primary,
                                  width: 4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: AppTheme.lightTheme.colorScheme.primary,
                                  width: 4,
                                ),
                                right: BorderSide(
                                  color: AppTheme.lightTheme.colorScheme.primary,
                                  width: 4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppTheme.lightTheme.colorScheme.primary,
                                  width: 4,
                                ),
                                left: BorderSide(
                                  color: AppTheme.lightTheme.colorScheme.primary,
                                  width: 4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppTheme.lightTheme.colorScheme.primary,
                                  width: 4,
                                ),
                                right: BorderSide(
                                  color: AppTheme.lightTheme.colorScheme.primary,
                                  width: 4,
                                ),
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
          ),

          // Top bar with controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close button
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Center(
                      child: CustomIconWidget(
                        iconName: 'close',
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),

                // Flash toggle button
                GestureDetector(
                  onTap: widget.onFlashToggle,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Center(
                      child: CustomIconWidget(
                        iconName: widget.isFlashOn ? 'flash_on' : 'flash_off',
                        color: widget.isFlashOn
                            ? AppTheme.lightTheme.colorScheme.primary
                            : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Instruction text
          Positioned(
            bottom: 25.h,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.isScanning
                        ? 'Scanning for barcode...'
                        : 'Position barcode within the frame',
                    style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Make sure the barcode is well-lit and clearly visible',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}