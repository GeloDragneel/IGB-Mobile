import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import '../providers/scan_provider.dart';
import '../providers/auth_provider.dart';

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
      // Handle error silently or show message
    } finally {}
  }

  Future<void> _scanReceipt() async {
    final picker = ImagePicker();
    List<File> selectedImages = [];

    bool takeMore = true;
    while (takeMore) {
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100, // Highest quality
        maxWidth: 2560, // Higher resolution
        maxHeight: 1440,
      );
      if (picked != null) {
        selectedImages.add(File(picked.path));
        // Ask if want to take more
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
            actionsAlignment: MainAxisAlignment.center, // Flutter 3.3+
            actions: [
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop(false), // Done = false
                child: const Text('Done'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop(true), // Add More = true
                child: const Text('Add More'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _performOCR(List<File> imageFiles) async {
    List<String> allTexts = [];
    final textRecognizer = TextRecognizer();

    for (File imageFile in imageFiles) {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      allTexts.add(recognizedText.text);
    }

    textRecognizer.close();

    String combinedText = allTexts.join('\n\n--- Next Receipt ---\n\n');

    Provider.of<ScanProvider>(
      context,
      listen: false,
    ).setScannedText(combinedText);

    setState(() {
      _combinedText = combinedText;
      _isProcessing = false;
    });

    // OCR done, ready for submit
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

    final pdf = pw.Document();
    final texts = combinedText.split('\n\n--- Next Receipt ---\n\n');

    for (int i = 0; i < imageFiles.length; i++) {
      final imageFile = imageFiles[i];
      final imageBytes = await imageFile.readAsBytes();
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Image(image),
                pw.Text(texts[i], style: pw.TextStyle(fontSize: 12)),
              ],
            );
          },
        ),
      );
    }

    // Save PDF to temp directory
    final output = await getTemporaryDirectory();
    final pdfFile = File('${output.path}/receipts.pdf');
    await pdfFile.writeAsBytes(await pdf.save());

    // Check if PDF was created
    if (!await pdfFile.exists()) {
      throw Exception('PDF file was not created');
    }

    // Upload PDF and text
    try {
      await _uploadToServer(pdfFile, combinedText);

      // Show success message and close dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Receipts uploaded successfully')),
        );
        widget.onUploadSuccess?.call();
        Navigator.of(context).pop(); // Close the dialog
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }

    setState(() {
      _isUploading = false;
    });
  }

  Future<void> _uploadToServer(File pdfFile, String text) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uri = Uri.parse(
      'https://igb-fems.com/LIVE/mobile_php/upload_receipt.php',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['userId'] = auth.userId.toString()
      ..fields['text'] = text
      ..fields['type'] = 'expenses'
      ..fields['accountCode'] = _selectedAccountCode ?? ''
      ..files.add(await http.MultipartFile.fromPath('pdf', pdfFile.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        'Upload failed: ${response.statusCode} - ${response.body}',
      );
    }

    // Parse JSON response
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
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                child: Image.file(image),
                minScale: 0.5,
                maxScale: 4.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF121826),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long,
                      color: Color(0xFF8f72ec),
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Scan Expenses Receipts',
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
                SizedBox(height: 20),
                // Scan button with better styling
                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.camera_alt, size: 20),
                    label: Text(
                      'Scan Receipts',
                      style: TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF8f72ec),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: (_isProcessing || _isUploading)
                        ? null
                        : _scanReceipt,
                  ),
                ),
                if (_isProcessing) ...[
                  SizedBox(height: 20),
                  CircularProgressIndicator(color: Colors.white),
                  Text(
                    'Processing images...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
                if (_isUploading) ...[
                  SizedBox(height: 20),
                  CircularProgressIndicator(color: Colors.white),
                  Text('Uploading...', style: TextStyle(color: Colors.white)),
                ],
                if (_images.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Scanned Images (${_images.length})',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    height: 280,
                    decoration: BoxDecoration(
                      color: Color(0xFF1A1D2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12, width: 1),
                    ),
                    child: ListView(
                      padding: EdgeInsets.all(12),
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
                                    boxShadow: [
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
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
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
                  SizedBox(height: 20),
                  // Account Selection Dropdown
                  Container(
                    width: double.infinity,
                    child: DropdownButtonFormField<String>(
                      value: _selectedAccountCode,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Select Expense Account',
                        labelStyle: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: Color(0xFF1A1D2E),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF8f72ec)),
                        ),
                      ),
                      dropdownColor: Color(0xFF1A1D2E),
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      items: _accounts.map((account) {
                        return DropdownMenuItem<String>(
                          value: account['code'],
                          child: Text(
                            '${account['code']} - ${account['name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedAccountCode = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select an expense account';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedAccountCode != null
                          ? () => _submitReceipts()
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedAccountCode != null
                            ? Color(0xFF8f72ec)
                            : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Submit Receipts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFe57373),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
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
