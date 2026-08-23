// lib/presentation/barcode_scanner/barcode_scanner.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/product_service.dart';
import './widgets/camera_overlay_widget.dart';
import './widgets/error_message_widget.dart';
import './widgets/manual_input_widget.dart';
import './widgets/scanning_animation_widget.dart';
import './widgets/success_flash_widget.dart';

class BarcodeScanner extends StatefulWidget {
  final bool isActive;

  /// Called when the user taps the close button while the scanner is embedded
  /// as a tab (where there is nothing to pop). Without this the close button
  /// was simply dead in the tab layout.
  final VoidCallback? onExitRequested;

  const BarcodeScanner({
    super.key,
    this.isActive = true,
    this.onExitRequested,
  });

  @override
  State<BarcodeScanner> createState() => _BarcodeScannerState();
}

class _BarcodeScannerState extends State<BarcodeScanner>
    with WidgetsBindingObserver {
  MobileScannerController? _scannerController;
  final ProductService _productService = ProductService();

  /// Formats that actually appear on packaged food. Without this filter any QR
  /// code in view triggered a product lookup that was guaranteed to fail.
  static const Set<BarcodeFormat> _productFormats = {
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
    BarcodeFormat.itf,
    BarcodeFormat.code128,
    BarcodeFormat.code39,
  };

  bool _isScanning = false;
  bool _isFlashOn = false;
  bool _showManualInput = false;
  bool _isLoading = false;
  bool _showSuccessFlash = false;
  String? _errorMessage;
  String? _errorTitle;
  bool _hasPermission = false;
  bool _isInitialized = false;

  /// Guards against the same code being processed twice while the details
  /// screen is opening.
  String? _lastHandledBarcode;
  DateTime? _lastHandledAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) {
      _initializeScanner();
    }
  }

  @override
  void didUpdateWidget(BarcodeScanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        if (_scannerController == null) {
          _initializeScanner();
        } else {
          _scannerController!.start();
        }
      } else {
        _scannerController?.stop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_scannerController == null || !_isInitialized || !widget.isActive) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (widget.isActive) {
          _scannerController!.start();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _scannerController!.stop();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _initializeScanner() async {
    try {
      if (!kIsWeb) {
        final permission = await Permission.camera.request();
        if (!permission.isGranted) {
          if (!mounted) return;
          setState(() {
            _hasPermission = false;
            _errorTitle = 'Camera Permission Required';
            _errorMessage = permission.isPermanentlyDenied
                ? 'Camera access is turned off for this app. Open Settings to enable it, then come back to scan.'
                : 'Please grant camera permission to scan barcodes.';
          });
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _hasPermission = true;
        _errorMessage = null;
        _errorTitle = null;
      });

      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
        formats: _productFormats.toList(),
      );

      await _scannerController!.start();

      if (!mounted) {
        // The user left while the camera was warming up — release it.
        await _scannerController?.dispose();
        _scannerController = null;
        return;
      }
      setState(() {
        _isInitialized = true;
        _isScanning = true;
      });
    } catch (e) {
      debugPrint('Scanner init failed: $e');
      if (!mounted) return;
      setState(() {
        _hasPermission = false;
        _errorTitle = 'Camera Error';
        _errorMessage =
            'Unable to access camera. Please check if another app is using the camera.';
      });
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isLoading || _showSuccessFlash) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      if (!_productFormats.contains(barcode.format)) continue;
      if (!_looksLikeProductBarcode(raw)) continue;

      // Ignore a repeat of the code we just handled (camera keeps firing while
      // the details route animates in).
      final now = DateTime.now();
      if (_lastHandledBarcode == raw &&
          _lastHandledAt != null &&
          now.difference(_lastHandledAt!) < const Duration(seconds: 3)) {
        return;
      }
      _lastHandledBarcode = raw;
      _lastHandledAt = now;

      _handleBarcodeFound(raw.trim());
      return;
    }
  }

  /// Product barcodes are 8–14 digits (EAN-8/UPC-E through GTIN-14).
  bool _looksLikeProductBarcode(String value) {
    final digits = value.trim();
    if (digits.length < 8 || digits.length > 14) return false;
    return RegExp(r'^\d+$').hasMatch(digits);
  }

  Future<void> _handleBarcodeFound(String barcode) async {
    if (_isLoading) return;

    HapticFeedback.lightImpact();

    setState(() {
      _isLoading = true;
      _isScanning = false;
      _showSuccessFlash = true;
    });

    // Show success flash animation
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() {
      _showSuccessFlash = false;
    });

    await _openProduct(barcode);
  }

  /// Shared lookup → save → navigate path for both scanning and manual entry.
  Future<void> _openProduct(String barcode) async {
    final product = await _productService.getProductByBarcode(barcode);
    if (!mounted) return;

    if (product == null) {
      setState(() {
        _isLoading = false;
        _errorTitle = 'Product Not Found';
        _errorMessage = "We couldn't find product info for barcode: $barcode.\n"
            'Try scanning again or enter the barcode manually.';
      });
      return;
    }

    // Persisting must never block navigation, but a total failure is worth
    // telling the user about — it used to fail completely silently.
    final saveResult = await _productService.saveToScanHistory(product);
    if (!mounted) return;
    if (!saveResult.isPersisted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't save this scan to your history."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (!mounted) return;
    await Navigator.pushNamed(
      context,
      '/product-details',
      arguments: product,
    );
    if (mounted) _resetScanner();
  }

  void _resetScanner() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isScanning = true;
      _showSuccessFlash = false;
      _errorMessage = null;
      _errorTitle = null;
      _showManualInput = false;
    });
    _lastHandledBarcode = null;
    _lastHandledAt = null;
  }

  Future<void> _toggleFlash() async {
    if (_scannerController == null || !_isInitialized) return;

    try {
      await _scannerController!.toggleTorch();
      if (!mounted) return;
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      debugPrint('Torch unsupported on this device: $e');
    }
  }

  void _showManualInputSheet() {
    setState(() {
      _showManualInput = true;
      _isScanning = false;
    });
  }

  Future<void> _handleManualSearch(String barcode) async {
    final trimmed = barcode.trim();
    if (!_looksLikeProductBarcode(trimmed)) {
      setState(() {
        _showManualInput = false;
        _errorTitle = 'Invalid Barcode';
        _errorMessage =
            'A product barcode is 8 to 14 digits. Please check the number and try again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _showManualInput = false;
    });

    await _openProduct(trimmed);
  }

  Future<void> _requestCameraPermission() async {
    if (kIsWeb) return;
    final permission = await Permission.camera.request();
    if (!mounted) return;
    if (permission.isGranted) {
      await _initializeScanner();
    } else if (permission.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  /// Pops when there is a route to pop, otherwise asks the host (tab shell) to
  /// move away. Previously this called `maybePop` unconditionally, which did
  /// nothing at all inside the bottom-nav shell.
  void _handleClose() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      widget.onExitRequested?.call();
    }
  }

  void _dismissError() {
    setState(() {
      _errorMessage = null;
      _errorTitle = null;
    });
    _resetScanner();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview or permission request
          if (widget.isActive && _hasPermission && _isInitialized && _scannerController != null)
            MobileScanner(
              controller: _scannerController!,
              onDetect: _onBarcodeDetected,
            )
          else
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomIconWidget(
                      iconName: 'camera_alt',
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 64,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _hasPermission
                          ? 'Initializing Camera...'
                          : 'Camera Access Needed',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    if (!_hasPermission) ...[
                      SizedBox(height: 2.h),
                      ElevatedButton(
                        onPressed: _requestCameraPermission,
                        child: const Text('Grant Permission'),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Camera overlay with scanning reticle
          if (_hasPermission && _isInitialized)
            CameraOverlayWidget(
              onClose: _handleClose,
              onFlashToggle: _toggleFlash,
              isFlashOn: _isFlashOn,
              isScanning: _isScanning,
            ),

          // Manual input bottom sheet
          if (_showManualInput)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ManualInputWidget(
                onSearch: _handleManualSearch,
                isLoading: _isLoading,
              ),
            ),

          // Floating action button for manual input
          if (_hasPermission &&
              _isInitialized &&
              !_showManualInput &&
              !_isLoading)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: _showManualInputSheet,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const CustomIconWidget(
                  iconName: 'keyboard',
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),

          // Scanning animation overlay
          ScanningAnimationWidget(
            isVisible: _isLoading && !_showSuccessFlash,
            message: 'Looking up product...',
          ),

          // Success flash animation
          SuccessFlashWidget(
            isVisible: _showSuccessFlash,
            onAnimationComplete: () {
              setState(() {
                _showSuccessFlash = false;
              });
            },
          ),

          // Error message overlay
          if (_errorMessage != null && _errorTitle != null)
            ErrorMessageWidget(
              title: _errorTitle!,
              message: _errorMessage!,
              actionText: _hasPermission ? 'Try Again' : 'Open Settings',
              onAction:
                  _hasPermission ? _dismissError : _requestCameraPermission,
              onDismiss: _hasPermission ? _dismissError : _handleClose,
            ),
        ],
      ),
    );
  }
}

