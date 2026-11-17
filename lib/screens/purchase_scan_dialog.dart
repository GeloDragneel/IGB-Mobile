import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
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
import '../constants/api_constants.dart';

class PurchaseScanDialog extends StatefulWidget {
  final VoidCallback? onUploadSuccess;
  const PurchaseScanDialog({super.key, this.onUploadSuccess});

  @override
  State<PurchaseScanDialog> createState() => _PurchaseScanDialogState();
}

class _PurchaseScanDialogState extends State<PurchaseScanDialog> {
  List<File> _images = [];
  List<File> _pdfs =
      []; // PDF files picked from the device (uploaded as they are)
  bool _isProcessing = false;
  bool _isUploading = false;
  String _combinedText = '';

  // ── Design tokens ─────────────────────────────────────────────
  static const _bg = Color(0xFFF4F6FB);
  static const _surface = Colors.white;
  static const _purple = Color(0xFF4F46E5);
  static const _purpleGlow = Color(0x1F4F46E5);
  static const _white = Colors.white; // text on indigo buttons / dark overlays
  static const _ink = Color(0xFF0F172A);
  static const _white70 = Color(0xFF64748B); // secondary text
  static const _white40 = Color(0xFF94A3B8); // faint text / icons
  static const _white12 = Color(0xFFE2E8F0); // borders
  static const _white08 = Color(0xFFE2E8F0);

  // ── Unchanged logic ───────────────────────────────────────────

  // Upload from devices → Photos or PDF file
  Future<void> _chooseUpload() async {
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              _sourceTile(
                ctx,
                'photos',
                Icons.photo_library_outlined,
                'Photos',
                'JPG / PNG – cropped and read (OCR)',
              ),
              const SizedBox(height: 8),
              _sourceTile(
                ctx,
                'pdf',
                Icons.picture_as_pdf_outlined,
                'PDF file',
                'Uploaded as it is – you can pick more than one',
              ),
            ],
          ),
        ),
      ),
    );
    if (pick == 'photos') await _selectFromGallery();
    if (pick == 'pdf') await _selectPdf();
  }

  Widget _sourceTile(
    BuildContext ctx,
    String value,
    IconData icon,
    String title,
    String sub,
  ) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _white12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _purpleGlow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _purple, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(color: _white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _white40),
          ],
        ),
      ),
    );
  }

  Future<void> _selectPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null) return;
    final picked = result.files
        .where((f) => f.path != null)
        .map((f) => File(f.path!))
        .toList();
    if (picked.isEmpty) return;
    setState(() {
      final have = _pdfs.map((f) => f.path).toSet();
      _pdfs = [..._pdfs, ...picked.where((f) => !have.contains(f.path))];
    });
  }

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
      if (images.isNotEmpty) {
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
            surfaceTintColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Center(
              child: Text(
                AppLocalizations.of(context).addAnotherReceipt,
                style: const TextStyle(
                  color: _ink,
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

  Future<void> _submitReceipts() async {
    if (_pdfs.isEmpty) return _createAndUploadPDF(_images, _combinedText);

    setState(() => _isUploading = true);
    try {
      // scanned / picked photos → one PDF (same as before)
      if (_images.isNotEmpty) {
        await _uploadToServer(await _imagesToPdf(_images), _combinedText);
      }
      // picked PDF files → uploaded as they are, one by one
      for (final f in _pdfs) {
        if (!await f.exists() || await f.length() == 0) {
          throw Exception('${f.path.split('/').last} is empty');
        }
        await _uploadToServer(f, '');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _ink,
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
            backgroundColor: const Color(0xFFDC2626),
            content: Text(
              'Upload failed: $e',
              style: const TextStyle(color: _white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // photos → one PDF file (one page per photo)
  Future<File> _imagesToPdf(List<File> imageFiles) async {
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
    if (await pdfFile.length() == 0) throw Exception('PDF file is empty');
    return pdfFile;
  }

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
            backgroundColor: _ink,
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
            backgroundColor: const Color(0xFFDC2626),
            content: Text(
              'Upload failed: $e',
              style: const TextStyle(color: Colors.white),
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
    final uri = Uri.parse('${ApiConstants.baseUrl}/upload_receipt');
    final request = http.MultipartRequest('POST', uri)
      ..fields['userId'] = auth.userId.toString()
      ..fields['employeeId'] = auth.employeeId.toString()
      ..fields['caid'] = auth.caid.toString()
      ..fields['text'] = text
      ..fields['type'] = 'purchases'; // ← purchases
    final pdfBytes = await pdfFile.readAsBytes();
    if (pdfBytes.isEmpty) throw Exception('PDF bytes are empty');
    request.files.add(
      http.MultipartFile.fromBytes(
        'pdf',
        pdfBytes,
        filename:
            pdfFile.path.toLowerCase().endsWith('.pdf') &&
                !pdfFile.path.split('/').last.startsWith('receipts_')
            ? pdfFile.path.split('/').last
            : 'receipts.pdf',
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
    final bool hasImages = _images.isNotEmpty || _pdfs.isNotEmpty;
    final bool canSubmit = hasImages && !busy;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(loc),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!hasImages) ...[
                      const SizedBox(height: 20),
                      Text(
                        loc.scanYourDocuments,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        loc.alignYourReceipt,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: busy ? null : _batchCameraScan,
                        child: const _ScanFrame(),
                      ),
                      const SizedBox(height: 16),
                      _buildTipBanner('💡 ${loc.scanTips}'),
                    ],

                    if (hasImages) ...[
                      const SizedBox(height: 16),
                      _buildCompactActionRow(loc, busy),
                    ],

                    if (busy) ...[
                      const SizedBox(height: 20),
                      _buildStatusCard(loc),
                    ],

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
                  ],
                ),
              ),
            ),
            // Bottom: Scan / Upload, or Submit once there are pages
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: _surface,
                border: Border(top: BorderSide(color: _white12)),
              ),
              child: hasImages
                  ? _buildSubmitButton(loc, canSubmit)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildScanButton(loc, busy),
                        const SizedBox(height: 10),
                        _buildUploadButton(loc, busy),
                      ],
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
        color: _surface,
        border: Border(bottom: BorderSide(color: _white08, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: _ink, size: 22),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _purpleGlow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: _purple,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            loc.purchases,
            style: const TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
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
        onPressed: busy ? null : _chooseUpload,
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
              onPressed: busy ? null : _chooseUpload,
            ),
          ),
        ),
      ],
    );
  }

  // ── Status card ───────────────────────────────────────────────
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
                  color: _ink,
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

  // ── Images header ─────────────────────────────────────────────
  Widget _buildImagesHeader(AppLocalizations loc) {
    return Row(
      children: [
        const Icon(Icons.photo_library_outlined, color: _white40, size: 16),
        const SizedBox(width: 8),
        Text(
          '${loc.scannedImages} (${_images.length + _pdfs.length})',
          style: const TextStyle(
            color: _ink,
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
      itemCount: _images.length + _pdfs.length,
      itemBuilder: (_, i) => i < _images.length
          ? _buildImageCard(_images[i], i + 1)
          : _buildPdfCard(_pdfs[i - _images.length], i + 1),
    );
  }

  Widget _buildPdfCard(File file, int index) {
    final name = file.path.split('/').last;
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _white12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFDC2626),
                    size: 42,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // page number badge
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          // remove this PDF
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, color: _white40, size: 18),
              onPressed: _isUploading
                  ? null
                  : () => setState(() => _pdfs.remove(file)),
            ),
          ),
        ],
      ),
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
              color: Color(0x140F172A),
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

// Scanner box: rounded viewfinder, indigo corner brackets, moving scan line
class _ScanFrame extends StatefulWidget {
  const _ScanFrame();

  @override
  State<_ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<_ScanFrame>
    with SingleTickerProviderStateMixin {
  static const _indigo = Color(0xFF4F46E5);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.85,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: CustomPaint(
          painter: const _CornerPainter(_indigo),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 76,
                      color: _indigo.withOpacity(0.18),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tap to scan',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) => Align(
                    alignment: Alignment(0, -0.9 + 1.8 * _c.value),
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: _indigo,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: _indigo.withOpacity(0.5),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 36.0, r = 14.0;
    const rad = Radius.circular(r);
    canvas.drawPath(
      Path()
        ..moveTo(0, l)
        ..lineTo(0, r)
        ..arcToPoint(const Offset(r, 0), radius: rad)
        ..lineTo(l, 0),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(s.width - l, 0)
        ..lineTo(s.width - r, 0)
        ..arcToPoint(Offset(s.width, r), radius: rad)
        ..lineTo(s.width, l),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(s.width, s.height - l)
        ..lineTo(s.width, s.height - r)
        ..arcToPoint(Offset(s.width - r, s.height), radius: rad)
        ..lineTo(s.width - l, s.height),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(l, s.height)
        ..lineTo(r, s.height)
        ..arcToPoint(Offset(0, s.height - r), radius: rad)
        ..lineTo(0, s.height - l),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}
