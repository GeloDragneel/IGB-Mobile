import 'dart:io';
import 'package:flutter/material.dart';
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

class ExpensesScanDialog extends StatefulWidget {
  final VoidCallback? onUploadSuccess;

  const ExpensesScanDialog({super.key, this.onUploadSuccess});

  @override
  State<ExpensesScanDialog> createState() => _ExpensesScanDialogState();
}

class _ExpensesScanDialogState extends State<ExpensesScanDialog> {
  List<File> _images = [];
  bool _isProcessing = false;
  bool _isUploading = false;
  String _combinedText = '';
  List<Map<String, String>> _accounts = [];
  String? _selectedAccountCode;

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse(
          'https://igb-fems.com/LIVE/mobile_php/charts_expenses.php?userId=${auth.userId}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] == 'Success') {
          final List<dynamic> invoices = data['invoices'];
          setState(() {
            _accounts = invoices
                .map<Map<String, String>>(
                  (account) => {
                    'code': account['AccountCode'].toString(),
                    'name': account['Account_Name'].toString(),
                  },
                )
                .toList();
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _scanReceipt() async {
    final documentScanner = doc_scanner.DocumentScanner(
      options: doc_scanner.DocumentScannerOptions(pageLimit: 10),
    );

    try {
      final result = await documentScanner.scanDocument();
      if (result.images.isNotEmpty) {
        setState(() {
          _images = result.images.map((path) => File(path)).toList();
          _isProcessing = true;
        });
        await _performOCR(_images);
      }
    } catch (e) {
      await _fallbackScanReceipt();
    } finally {
      documentScanner.close();
    }
  }

  Future<void> _fallbackScanReceipt() async {
    final picker = ImagePicker();
    List<File> selectedImages = [];

    bool takeMore = true;
    while (takeMore) {
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        maxWidth: 2560,
        maxHeight: 1440,
      );
      if (picked != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: picked.path,
        );
        if (croppedFile != null) {
          selectedImages.add(File(croppedFile.path));
        }
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
            title: const Center(child: Text('Add another receipt?')),
            content: const Text(
              'Do you want to scan another receipt?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Done'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Add More'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _selectFromGallery() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      imageQuality: 100,
      maxWidth: 2560,
      maxHeight: 1440,
    );

    if (pickedFiles.isNotEmpty) {
      List<File> selectedImages = [];
      for (var pickedFile in pickedFiles) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
        );
        if (croppedFile != null) {
          selectedImages.add(File(croppedFile.path));
        } else {
          selectedImages.add(File(pickedFile.path));
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
  }

  Future<void> _batchCameraScan() async {
    final picker = ImagePicker();
    List<File> selectedImages = [];

    bool takeMore = true;
    while (takeMore) {
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        maxWidth: 2560,
        maxHeight: 1440,
      );
      if (picked != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: picked.path,
        );
        if (croppedFile != null) {
          selectedImages.add(File(croppedFile.path));
        }
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

  Future<void> _performOCR(List<File> imageFiles) async {
    List<String> allTexts = [];
    final textRecognizer = TextRecognizer();

    for (File imageFile in imageFiles) {
      try {
        final inputImage = InputImage.fromFile(imageFile);
        final RecognizedText recognizedText = await textRecognizer.processImage(
          inputImage,
        );
        allTexts.add(recognizedText.text);
      } catch (e) {
        allTexts.add('[OCR failed for this image]');
      }
    }

    textRecognizer.close();

    final String combinedText = allTexts.join('\n\n--- Next Receipt ---\n\n');

    Provider.of<ScanProvider>(
      context,
      listen: false,
    ).setScannedText(combinedText);

    setState(() {
      _combinedText = combinedText;
      _isProcessing = false;
    });
  }

  Future<void> _submitReceipts() async {
    await _createAndUploadPDF(_images, _combinedText);
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
      final texts = combinedText.split('\n\n--- Next Receipt ---\n\n');

      for (int i = 0; i < imageFiles.length; i++) {
        final imageFile = imageFiles[i];
        final imageBytes = await imageFile.readAsBytes();

        if (imageBytes.isEmpty) {
          throw Exception('Image $i is empty');
        }

        final image = pw.MemoryImage(imageBytes);
        final pageText = (i < texts.length) ? texts[i] : '';

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context ctx) {
              return pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain));
            },
          ),
        );
      }

      final output = await getTemporaryDirectory();
      final pdfFile = File(
        '${output.path}/receipts_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      final pdfBytes = await pdf.save();

      if (pdfBytes.isEmpty) {
        throw Exception('Generated PDF is empty');
      }

      await pdfFile.writeAsBytes(pdfBytes, flush: true);
      await Future.delayed(const Duration(milliseconds: 100));

      if (!await pdfFile.exists()) {
        throw Exception('PDF file was not created');
      }

      final fileSize = await pdfFile.length();
      if (fileSize == 0) {
        throw Exception('PDF file is empty (0 bytes)');
      }

      await _uploadToServer(pdfFile, combinedText);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipts uploaded successfully')),
        );
        widget.onUploadSuccess?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _uploadToServer(File pdfFile, String text) async {
    if (!await pdfFile.exists()) {
      throw Exception('PDF file does not exist');
    }

    final fileSize = await pdfFile.length();
    if (fileSize == 0) {
      throw Exception('PDF file is empty before upload');
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uri = Uri.parse(
      'https://igb-fems.com/LIVE/mobile_php/upload_receipt.php',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['userId'] = auth.userId.toString()
      ..fields['text'] = text
      ..fields['type'] = 'expenses'
      ..fields['accountCode'] = _selectedAccountCode ?? '';

    final pdfBytes = await pdfFile.readAsBytes();

    if (pdfBytes.isEmpty) {
      throw Exception('PDF bytes are empty');
    }

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

    if (response.statusCode != 200) {
      throw Exception(
        'Upload failed: ${response.statusCode} - ${response.body}',
      );
    }

    final responseData = json.decode(response.body);
    if (responseData['success'] != true) {
      throw Exception('Server error: ${responseData['message']}');
    }
  }

  void _showFullImage(File image) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(image),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF121826),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.receipt_long,
                      color: Color(0xFF8f72ec),
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Expenses',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Scan options
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt, size: 20),
                        label: const Text(
                          'Scan',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8f72ec),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: (_isProcessing || _isUploading)
                            ? null
                            : _scanReceipt,
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.photo_library, size: 20),
                        label: const Text(
                          'Upload from Devices',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: (_isProcessing || _isUploading)
                            ? null
                            : _selectFromGallery,
                      ),
                    ),
                    // Expense Account dropdown placed right after Upload from Devices
                    _SearchableAccountField(
                      accounts: _accounts,
                      selectedAccountCode: _selectedAccountCode,
                      onChanged: (value) {
                        setState(() {
                          _selectedAccountCode = value;
                        });
                      },
                    ),
                  ],
                ),

                if (_isProcessing) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    'Processing images...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],

                if (_isUploading) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    'Uploading...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],

                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Scanned Images (${_images.length})',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 280,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12, width: 1),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: _images
                          .map(
                            (image) => Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: GestureDetector(
                                onTap: () => _showFullImage(image),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.white24,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      children: [
                                        Image.file(
                                          image,
                                          height: 200,
                                          width: double.infinity,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.high,
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.zoom_in,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],

                if (_images.isNotEmpty && !_isProcessing && !_isUploading) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedAccountCode != null
                          ? () => _submitReceipts()
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedAccountCode != null
                            ? const Color(0xFF8f72ec)
                            : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Submit Receipts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFe57373),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Searchable Account Field
// ---------------------------------------------------------------------------

class _SearchableAccountField extends StatefulWidget {
  final List<Map<String, String>> accounts;
  final String? selectedAccountCode;
  final ValueChanged<String?> onChanged;

  const _SearchableAccountField({
    required this.accounts,
    required this.selectedAccountCode,
    required this.onChanged,
  });

  @override
  State<_SearchableAccountField> createState() =>
      _SearchableAccountFieldState();
}

class _SearchableAccountFieldState extends State<_SearchableAccountField> {
  final TextEditingController _searchController = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  List<Map<String, String>> _filtered = [];
  String _displayText = '';

  @override
  void initState() {
    super.initState();
    _filtered = widget.accounts;
    _syncDisplayText();
  }

  @override
  void didUpdateWidget(_SearchableAccountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accounts != widget.accounts ||
        oldWidget.selectedAccountCode != widget.selectedAccountCode) {
      _filtered = widget.accounts;
      _syncDisplayText();
    }
  }

  void _syncDisplayText() {
    if (widget.selectedAccountCode != null) {
      final match = widget.accounts.firstWhere(
        (a) => a['code'] == widget.selectedAccountCode,
        orElse: () => {},
      );
      _displayText = match.isNotEmpty
          ? '${match['code']} - ${match['name']}'
          : '';
    } else {
      _displayText = '';
    }
  }

  void _filter(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filtered = widget.accounts.where((a) {
        return (a['code'] ?? '').toLowerCase().contains(q) ||
            (a['name'] ?? '').toLowerCase().contains(q);
      }).toList();
    });
    _overlayEntry?.markNeedsBuild();
  }

  void _openDropdown() {
    if (_isOpen) return;
    _searchController.clear();
    _filtered = widget.accounts;
    _isOpen = true;
    _overlayEntry = _buildOverlay();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeDropdown() {
    if (!_isOpen) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
  }

  void _selectAccount(Map<String, String> account) {
    widget.onChanged(account['code']);
    setState(() {
      _displayText = '${account['code']} - ${account['name']}';
    });
    _closeDropdown();
  }

  OverlayEntry _buildOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF8f72ec), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search input inside overlay
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      cursorColor: const Color(0xFF8f72ec),
                      decoration: InputDecoration(
                        hintText: 'Search by code or name...',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white38,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0D1017),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: _filter,
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  // Results list
                  Flexible(
                    child: StatefulBuilder(
                      builder: (ctx, setInnerState) {
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          itemCount: _filtered.isEmpty ? 1 : _filtered.length,
                          itemBuilder: (ctx, index) {
                            if (_filtered.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No accounts found',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            final account = _filtered[index];
                            final isSelected =
                                account['code'] == widget.selectedAccountCode;
                            return InkWell(
                              onTap: () => _selectAccount(account),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                color: isSelected
                                    ? const Color(0xFF8f72ec).withOpacity(0.2)
                                    : Colors.transparent,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF8f72ec,
                                        ).withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        account['code'] ?? '',
                                        style: const TextStyle(
                                          color: Color(0xFF8f72ec),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        account['name'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check,
                                        color: Color(0xFF8f72ec),
                                        size: 16,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _closeDropdown();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _isOpen ? _closeDropdown : _openDropdown,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isOpen ? const Color(0xFF8f72ec) : Colors.white24,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _displayText.isEmpty
                    ? const Text(
                        'Select Expense Account',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      )
                    : Text(
                        _displayText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              Icon(
                _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.white54,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
