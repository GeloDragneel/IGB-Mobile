import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart'
    as doc_scanner;
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import '../providers/scan_provider.dart';
import '../providers/auth_provider.dart';
import 'package:http_parser/http_parser.dart';
import '../l10n/app_localizations.dart';

class SalesScanDialog extends StatefulWidget {
  final VoidCallback? onUploadSuccess;
  const SalesScanDialog({super.key, this.onUploadSuccess});

  @override
  State<SalesScanDialog> createState() => _SalesScanDialogState();
}

class _SalesScanDialogState extends State<SalesScanDialog> {
  List<File> _images = [];
  bool _isProcessing = false;
  bool _isUploading = false;
  String _combinedText = '';

  // ── Design tokens ─────────────────────────────────────────────
  static const _bg = Color(0xFF0F1623);
  static const _surface = Color(0xFF1A1F2E);
  static const _purple = Color(0xFF8F72EC);
  static const _purpleGlow = Color(0x338F72EC);
  static const _white = Colors.white;
  static const _white70 = Color(0xB3FFFFFF);
  static const _white40 = Color(0x66FFFFFF);
  static const _white12 = Color(0x1FFFFFFF);
  static const _white08 = Color(0x14FFFFFF);

  // ── Unchanged logic ───────────────────────────────────────────

  Future<void> _selectFromGallery() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      imageQuality: 100,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (pickedFiles.isNotEmpty) {
      List<File> selectedImages = [];
      for (var pf in pickedFiles) {
        final c = await ImageCropper().cropImage(sourcePath: pf.path);
        selectedImages.add(c != null ? File(c.path) : File(pf.path));
      }
      if (selectedImages.isNotEmpty) {
        setState(() {
          _images = selectedImages;
          _isProcessing = true;
        });
        await _performOCR(_images);
      }
    }
  }

  Future<void> _batchCameraScan() async {
    final documentScanner = doc_scanner.DocumentScanner(
      options: doc_scanner.DocumentScannerOptions(pageLimit: 99),
    );
    try {
      final result = await documentScanner.scanDocument();
      final images = result.images;
      if (images != null && images.isNotEmpty) {
        setState(() {
          _images = images.map((p) => File(p)).toList();
          _isProcessing = true;
        });
        await _performOCR(_images);
      }
    } catch (e) {
      await _fallbackBatchCameraScan();
    } finally {
      documentScanner.close();
    }
  }

  Future<void> _fallbackBatchCameraScan() async {
    final picker = ImagePicker();
    List<File> selectedImages = [];
    bool takeMore = true;
    while (takeMore) {
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (picked != null) {
        final c = await ImageCropper().cropImage(sourcePath: picked.path);
        if (c != null) selectedImages.add(File(c.path));
        takeMore = await _askTakeMore();
      } else {
        takeMore = false;
      }
    }
    if (selectedImages.isNotEmpty) {
      setState(() {
        _images = selectedImages;
        _isProcessing = true;
      });
      await _performOCR(_images);
    }
  }

  Future<bool> _askTakeMore() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Center(
              child: Text(
                AppLocalizations.of(context).addAnotherReceipt,
                style: const TextStyle(
                  color: _white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            content: Text(
              AppLocalizations.of(context).doYouWantAnotherReceipt,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _white70),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _white70,
                  side: const BorderSide(color: _white12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(AppLocalizations.of(context).done),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: _white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(AppLocalizations.of(context).addMore),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _performOCR(List<File> imageFiles) async {
    final loc = AppLocalizations.of(context);
    final scanProvider = Provider.of<ScanProvider>(context, listen: false);
    List<String> allTexts = [];
    final textRecognizer = TextRecognizer();
    for (File imageFile in imageFiles) {
      try {
        final inputImage = InputImage.fromFile(imageFile);
        final RecognizedText rt = await textRecognizer.processImage(inputImage);
        allTexts.add(rt.text);
      } catch (_) {
        allTexts.add(loc.ocrFailed);
      }
    }
    textRecognizer.close();
    final combinedText = allTexts.join('\n\n--- ${loc.nextReceipt} ---\n\n');
    if (!mounted) return;
    scanProvider.setScannedText(combinedText);
    setState(() {
      _combinedText = combinedText;
      _isProcessing = false;
    });
  }

  Future<void> _submitReceipts() async =>
      await _createAndUploadPDF(_images, _combinedText);

  Future<void> _createAndUploadPDF(
    List<File> imageFiles,
    String combinedText,
  ) async {
    setState(() {
      _isUploading = true;
    });
    try {
      final pdf = pw.Document();
      for (int i = 0; i < imageFiles.length; i++) {
        final imageBytes = await imageFiles[i].readAsBytes();
        if (imageBytes.isEmpty) throw Exception('Image $i is empty');
        final image = pw.MemoryImage(imageBytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context ctx) =>
                pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
          ),
        );
      }
      final pdfBytes = await pdf.save();
      if (pdfBytes.isEmpty) throw Exception('Generated PDF is empty');
      final output = await getTemporaryDirectory();
      final pdfFile = File(
        '${output.path}/receipts_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await pdfFile.writeAsBytes(pdfBytes, flush: true);
      await Future.delayed(const Duration(milliseconds: 100));
      if (!await pdfFile.exists()) throw Exception('PDF file was not created');
      if (await pdfFile.length() == 0) throw Exception('PDF file is empty');
      await _uploadToServer(pdfFile, combinedText);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _surface,
            content: Text(
              AppLocalizations.of(context).receiptUploadSuccess,
              style: const TextStyle(color: _white),
            ),
          ),
        );
        try {
          widget.onUploadSuccess?.call();
        } catch (_) {}
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3D1A1A),
            content: Text(
              'Upload failed: $e',
              style: const TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        );
      }
    } finally {
      if (mounted)
        setState(() {
          _isUploading = false;
        });
    }
  }

  Future<void> _uploadToServer(File pdfFile, String text) async {
    if (!await pdfFile.exists()) throw Exception('PDF file does not exist');
    if (await pdfFile.length() == 0) throw Exception('PDF file is empty');
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uri = Uri.parse(
      'https://igb-fems.com/LIVE/mobile_php/upload_receipt.php',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['userId'] = auth.userId.toString()
      ..fields['text'] = text
      ..fields['type'] = 'sales';
    final pdfBytes = await pdfFile.readAsBytes();
    if (pdfBytes.isEmpty) throw Exception('PDF bytes are empty');
    request.files.add(
      http.MultipartFile.fromBytes(
        'pdf',
        pdfBytes,
        filename: 'receipts.pdf',
        contentType: MediaType('application', 'pdf'),
      ),
    );
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200)
      throw Exception('Upload failed: ${response.statusCode}');
    final responseData = json.decode(response.body);
    if (responseData['success'] != true)
      throw Exception('Server error: ${responseData['message']}');
  }

  void _showFullImage(File image) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                image,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 48,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(Icons.close, color: _white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final bool busy = _isProcessing || _isUploading;
    final bool canSubmit = _images.isNotEmpty && !busy;
    final bool hasImages = _images.isNotEmpty;

    // Make status bar icons light on dark bg
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ─────────────────────────────────────
            _buildAppBar(loc),

            // ── Scrollable content ──────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Empty state illustration
                    if (!hasImages) ...[
                      const SizedBox(height: 16),
                      _buildIllustrationCard(loc),
                      const SizedBox(height: 16),
                      _buildTipBanner(
                        '💡 ${AppLocalizations.of(context).scanTips}',
                      ),
                      const SizedBox(height: 24),
                      _buildScanButton(loc, busy),
                      const SizedBox(height: 12),
                      _buildUploadButton(loc, busy),
                    ],

                    // Has images state
                    if (hasImages) ...[
                      const SizedBox(height: 16),
                      _buildCompactActionRow(loc, busy),
                    ],

                    // Status card
                    if (busy) ...[
                      const SizedBox(height: 20),
                      _buildStatusCard(loc),
                    ],

                    // Images grid
                    if (hasImages) ...[
                      const SizedBox(height: 24),
                      _buildImagesHeader(loc),
                      const SizedBox(height: 12),
                      _buildImagesGrid(),
                      const SizedBox(height: 16),
                      _buildTipBanner(
                        '💡 ${AppLocalizations.of(context).previewTips}',
                      ),
                    ],

                    // Bottom actions
                    if (hasImages) ...[
                      const SizedBox(height: 28),
                      _buildSubmitButton(loc, canSubmit),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────
  Widget _buildAppBar(AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(bottom: BorderSide(color: _white08, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: _white, size: 22),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _purpleGlow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: _purple,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  loc.sales,
                  style: const TextStyle(
                    color: _white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Illustration card ─────────────────────────────────────────
  Widget _buildIllustrationCard(AppLocalizations loc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _white12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow behind icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _purpleGlow,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: _purpleGlow,
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: _purple,
                    size: 52,
                  ),
                ),
                Positioned(
                  top: 4,
                  left: 20,
                  child: _FloatingBadge(
                    color: const Color(0xFF4A90D9),
                    icon: Icons.attach_money,
                    size: 20,
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 16,
                  child: _FloatingBadge(
                    color: _purple,
                    icon: Icons.local_offer,
                    size: 18,
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 8,
                  child: _FloatingBadge(
                    color: const Color(0xFF1DC99A),
                    icon: Icons.attach_money,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context).scanYourDocuments,
            style: TextStyle(
              color: _white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context).alignYourReceipt,
            textAlign: TextAlign.center,
            style: TextStyle(color: _white40, fontSize: 13.5, height: 1.6),
          ),
        ],
      ),
    );
  }

  // ── Tip banner ────────────────────────────────────────────────
  Widget _buildTipBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _purple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _purple.withOpacity(0.2)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: _purple.withOpacity(0.9),
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ── Full-width scan button ────────────────────────────────────
  Widget _buildScanButton(AppLocalizations loc, bool busy) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.crop_free_rounded, size: 20),
        label: Text(
          loc.scan,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _purple,
          foregroundColor: _white,
          disabledBackgroundColor: _purple.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        onPressed: busy ? null : _batchCameraScan,
      ),
    );
  }

  // ── Full-width upload button ──────────────────────────────────
  Widget _buildUploadButton(AppLocalizations loc, bool busy) {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.photo_library_outlined, size: 20),
        label: Text(
          loc.uploadFromDevices,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _white70,
          side: const BorderSide(color: _white12, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: busy ? null : _selectFromGallery,
      ),
    );
  }

  // ── Compact action row (after images loaded) ──────────────────
  Widget _buildCompactActionRow(AppLocalizations loc, bool busy) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt_rounded, size: 17),
              label: Text(
                loc.scan,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: _white,
                disabledBackgroundColor: _purple.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: busy ? null : _batchCameraScan,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined, size: 17),
              label: Text(
                loc.uploadFromDevices,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _white70,
                side: const BorderSide(color: _white12, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: busy ? null : _selectFromGallery,
            ),
          ),
        ),
      ],
    );
  }

  // ── Status card with progress bar ─────────────────────────────
  Widget _buildStatusCard(AppLocalizations loc) {
    final label = _isProcessing ? loc.processingImage : loc.uploading;
    final pct = _isProcessing ? 0.6 : 0.85;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: _purple,
                  strokeWidth: 2.2,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: _white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(pct * 100).toInt()}%',
                style: const TextStyle(
                  color: _purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: _white12,
              color: _purple,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ── Images section header ─────────────────────────────────────
  Widget _buildImagesHeader(AppLocalizations loc) {
    return Row(
      children: [
        const Icon(Icons.photo_library_outlined, color: _white40, size: 16),
        const SizedBox(width: 8),
        Text(
          '${loc.scannedImages} (${_images.length})',
          style: const TextStyle(
            color: _white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ── Images grid ───────────────────────────────────────────────
  Widget _buildImagesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: _images.length,
      itemBuilder: (_, i) => _buildImageCard(_images[i], i + 1),
    );
  }

  Widget _buildImageCard(File image, int index) {
    return GestureDetector(
      onTap: () => _showFullImage(image),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _white12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(image, fit: BoxFit.cover),
              // Gradient overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 50,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                ),
              ),
              // Page number badge
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _purple.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: _white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Zoom icon
              const Positioned(
                bottom: 8,
                right: 8,
                child: Icon(
                  Icons.zoom_in_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Submit button ─────────────────────────────────────────────
  Widget _buildSubmitButton(AppLocalizations loc, bool canSubmit) {
    return AnimatedOpacity(
      opacity: canSubmit ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 250),
      child: SizedBox(
        height: 56,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
          label: Text(
            loc.submitReceipts,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _purple,
            foregroundColor: _white,
            disabledBackgroundColor: _purple.withOpacity(0.35),
            disabledForegroundColor: _white40,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: canSubmit ? 4 : 0,
            shadowColor: _purpleGlow,
          ),
          onPressed: canSubmit ? _submitReceipts : null,
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────

class _FloatingBadge extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double size;
  const _FloatingBadge({
    required this.color,
    required this.icon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 12,
      height: size + 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.45),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size),
    );
  }
}
