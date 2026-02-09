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
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import '../providers/scan_provider.dart';
import '../providers/auth_provider.dart';
import 'package:http_parser/http_parser.dart';

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

  Future<void> _scanReceipt() async {
    final documentScanner = doc_scanner.DocumentScanner(
      options: doc_scanner.DocumentScannerOptions(
        pageLimit: 10, // Allow batch scanning up to 10 pages
      ),
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
      // Fallback to manual camera + crop if document scanner fails
      await _fallbackScanReceipt();
    } finally {
      documentScanner.close();
    }
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

      for (var pickedFile in pickedFiles) {
        // Optional: Crop each selected image
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
    final documentScanner = doc_scanner.DocumentScanner(
      options: doc_scanner.DocumentScannerOptions(
        pageLimit: 10, // Allow batch scanning up to 10 pages
      ),
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
      // Fallback to manual batch camera scan
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

  Future<void> _fallbackScanReceipt() async {
    final picker = ImagePicker();
    List<File> selectedImages = [];

    bool takeMore = true;
    while (takeMore) {
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100, // Highest quality
        maxWidth: 1920, // High resolution
        maxHeight: 1080,
      );
      if (picked != null) {
        // Crop the image
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: picked.path,
        );
        if (croppedFile != null) {
          selectedImages.add(File(croppedFile.path));
        }
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

    try {
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
                  pw.SizedBox(height: 10),
                  pw.Text(texts[i], style: pw.TextStyle(fontSize: 12)),
                ],
              );
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

      print('PDF size: ${pdfBytes.length} bytes');

      await pdfFile.writeAsBytes(pdfBytes, flush: true);
      await Future.delayed(Duration(milliseconds: 100));

      if (!await pdfFile.exists()) {
        throw Exception('PDF file was not created');
      }

      final fileSize = await pdfFile.length();
      if (fileSize == 0) {
        throw Exception('PDF file is empty (0 bytes)');
      }

      print(
        'PDF file created successfully: ${pdfFile.path}, size: $fileSize bytes',
      );

      await _uploadToServer(pdfFile, combinedText);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Receipts uploaded successfully')),
        );
        widget.onUploadSuccess?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error in _createAndUploadPDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
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

    print('Uploading PDF: ${pdfFile.path}, size: $fileSize bytes');

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uri = Uri.parse(
      'https://igb-fems.com/LIVE/mobile_php/upload_receipt.php',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['userId'] = auth.userId.toString()
      ..fields['text'] = text
      ..fields['type'] = 'sales';

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

    print('Sending request with PDF size: ${pdfBytes.length} bytes');

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

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
          maxWidth: 400,
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
                  children: [
                    Icon(
                      Icons.receipt_long,
                      color: Color(0xFF8f72ec),
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Sales',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // Scan options
                Column(
                  children: [
                    // Scan
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 8),
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.camera_alt, size: 20),
                        label: Text('Scan', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF8f72ec),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: (_isProcessing || _isUploading)
                            ? null
                            : _batchCameraScan,
                      ),
                    ),
                    // Upload from Devices
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 8),
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.photo_library, size: 20),
                        label: Text(
                          'Upload from Devices',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: (_isProcessing || _isUploading)
                            ? null
                            : _selectFromGallery,
                      ),
                    ),
                  ],
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
                                          height: 160,
                                          width: double.infinity,
                                          fit: BoxFit.contain,
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
                  Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _submitReceipts(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF8f72ec),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
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
                      padding: EdgeInsets.symmetric(vertical: 14),
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
