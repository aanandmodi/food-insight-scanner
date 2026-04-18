// lib/presentation/barcode_scanner/barcode_scanner.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/services/product_service.dart';
import './widgets/camera_overlay_widget.dart';
import './widgets/error_message_widget.dart';
import './widgets/manual_input_widget.dart';
import './widgets/scanning_animation_widget.dart';
import './widgets/success_flash_widget.dart';

class BarcodeScanner extends StatefulWidget {
  const BarcodeScanner({super.key});

  @override
  State<BarcodeScanner> createState() => _BarcodeScannerState();
}

class _BarcodeScannerState extends State<BarcodeScanner>
    with WidgetsBindingObserver {
  MobileScannerController? _scannerController;
  final ProductService _productService = ProductService();

  bool _isScanning = false;
  bool _isFlashOn = false;
  bool _showManualInput = false;
  bool _isLoading = false;
  bool _showSuccessFlash = false;
  String? _errorMessage;
  String? _errorTitle;
  bool _hasPermission = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScanner();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_scannerController == null || !_isInitialized) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _scannerController!.start();
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
          setState(() {
            _hasPermission = false;
            _errorTitle = 'Camera Permission Required';
            _errorMessage =
                'Please grant camera permission to scan barcodes. You can enable it in your device settings.';
          });
          return;
        }
      }

      setState(() {
        _hasPermission = true;
        _errorMessage = null;
        _errorTitle = null;
      });

      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );

      await _scannerController!.start();

      setState(() {
        _isInitialized = true;
        _isScanning = true;
      });
    } catch (e) {
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

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      if (barcode.rawValue != null) {
        _handleBarcodeFound(barcode.rawValue!);
      }
    }
  }

  Future<void> _handleBarcodeFound(String barcode) async {
    if (_isLoading) return;

    // Haptic feedback
    HapticFeedback.lightImpact();

    setState(() {
      _isLoading = true;
      _isScanning = false;
      _showSuccessFlash = true;
    });

    // Show success flash animation
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _showSuccessFlash = false;
    });

    // Fetch real product data from Open Food Facts
    final product = await _productService.getProductByBarcode(barcode);

    if (product != null && mounted) {
      // Save to scan history
      await _productService.saveToScanHistory(product);

      if (!mounted) return;
      // Navigate to product details
      Navigator.pushNamed(
        context,
        '/product-details',
        arguments: product,
      ).then((_) {
        if (mounted) _resetScanner();
      });
    } else if (mounted) {
      // Product not found
      setState(() {
        _isLoading = false;
        _errorTitle = 'Product Not Found';
        _errorMessage =
            'We couldn\'t find product info for barcode: $barcode.\n'
            'Try scanning again or enter the barcode manually.';
      });
    }
  }

  void _resetScanner() {
    setState(() {
      _isLoading = false;
      _isScanning = true;
      _showSuccessFlash = false;
      _errorMessage = null;
      _errorTitle = null;
      _showManualInput = false;
    });
  }

  Future<void> _toggleFlash() async {
    if (_scannerController == null || !_isInitialized) return;

    try {
      await _scannerController!.toggleTorch();
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      // Flash not supported, ignore silently
    }
  }

  void _showManualInputSheet() {
    setState(() {
      _showManualInput = true;
      _isScanning = false;
    });
  }

  Future<void> _handleManualSearch(String barcode) async {
    setState(() {
      _isLoading = true;
      _showManualInput = false;
    });

    final product = await _productService.getProductByBarcode(barcode);

    if (product != null && mounted) {
      await _productService.saveToScanHistory(product);

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/product-details',
        arguments: product,
      ).then((_) {
        if (mounted) _resetScanner();
      });
    } else if (mounted) {
      setState(() {
        _isLoading = false;
        _errorTitle = 'Product Not Found';
        _errorMessage =
            'No product found with barcode: $barcode.\nPlease check the number and try again.';
      });
    }
  }

  void _requestCameraPermission() async {
    if (!kIsWeb) {
      final permission = await Permission.camera.request();
      if (permission.isGranted) {
        _initializeScanner();
      } else if (permission.isPermanentlyDenied) {
        openAppSettings();
      }
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
          if (_hasPermission && _isInitialized && _scannerController != null)
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
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
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
              onClose: () => Navigator.of(context).pop(),
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
                backgroundColor: AppTheme.lightTheme.primaryColor,
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
              onDismiss: _hasPermission
                  ? _dismissError
                  : () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }
}