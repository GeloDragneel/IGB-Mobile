import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../providers/auth_provider.dart';
import '../widgets/navigation_drawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Map<String, dynamic>> documents = [];

  @override
  void initState() {
    super.initState();
    fetchDocuments();
  }

  Future<void> fetchDocuments() async {
    final response = await http.get(
      Uri.parse('https://igb-fems.com/LIVE/mobile_php/documents.php'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['result'] == 'Success') {
        setState(() {
          documents = List<Map<String, dynamic>>.from(data['invoices']);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      drawer: AppDrawer(selectedIndex: 1),
      backgroundColor: const Color(0xFF121826),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header Card
            Card(
              color: const Color(0xFF1e293b),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, size: 60, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      auth.fullName.isNotEmpty ? auth.fullName : 'Full Name',
                      style: const TextStyle(
                        fontSize: 26,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      auth.username.isNotEmpty ? auth.username : 'Username',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            // Accordion Sections
            Card(
              color: const Color(0xFF1e293b),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                title: const Text(
                  'Personal Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                iconColor: Colors.white,
                collapsedIconColor: Colors.white,
                childrenPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.person_outline,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'Full Name',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      auth.fullName,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.account_circle,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'Username',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      auth.username,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Card(
              color: const Color(0xFF1e293b),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                title: const Text(
                  'Business Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                iconColor: Colors.white,
                collapsedIconColor: Colors.white,
                childrenPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  ListTile(
                    leading: const Icon(Icons.business, color: Colors.white70),
                    title: const Text(
                      'Trade Name',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      auth.tradeName,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.location_on,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'Branch Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      auth.branchCode,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.category, color: Colors.white70),
                    title: const Text(
                      'Branch Type',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      auth.branchType,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.numbers, color: Colors.white70),
                    title: const Text(
                      'Client Number',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      auth.clientNum,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.credit_card,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'TIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      auth.tin,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Card(
              color: const Color(0xFF1e293b),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                title: const Text(
                  'Documents',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                iconColor: Colors.white,
                collapsedIconColor: Colors.white,
                childrenPadding: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 8,
                ),
                children: documents.map((doc) {
                  return ListTile(
                    leading: const Icon(
                      Icons.file_copy_rounded,
                      color: Colors.white70,
                    ),
                    title: Text(
                      doc['DocumentName'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => _showDocumentImage(
                      context,
                      doc['DocumentName'],
                      'https://igb-fems.com/LIVE/images/Documents/${auth.comId}-${doc['ID']}.webp?v=${DateTime.now().millisecondsSinceEpoch}', // Using timestamp as version
                      doc['ID'],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDocumentImage(
    BuildContext context,
    String title,
    String imageUrl,
    String id,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.zero,
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1e293b),
                   
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Image
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(child: Text('Failed to load image'));
                      },
                    ),
                  ),
                ),
                // Upload Button at bottom
                Container(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: () => _uploadImage(context, id, title, imageUrl),
                    icon: const Icon(Icons.upload),
                    label: const Text('Change/Upload Image'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _uploadImage(
    BuildContext context,
    String id,
    String title,
    String imageUrl,
  ) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final filename = '${auth.comId}-$id.webp';

      // Show loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Uploading image...')));

      try {
        // Read image bytes
        final bytes = await image.readAsBytes();

        // Create multipart request
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://igb-fems.com/LIVE/mobile_php/upload_document.php'),
        );

        // Add file
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: filename,
            contentType: MediaType('image', 'webp'),
          ),
        );

        // Add other fields if needed
        request.fields['comId'] = auth.comId;
        request.fields['id'] = id;

        // Send request
        final response = await request.send();
        final responseBody = await response.stream.bytesToString();

        if (response.statusCode == 200) {
          final responseData = json.decode(responseBody);
          if (responseData['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image uploaded successfully')),
            );
            // Close the dialog and reopen it to refresh the image
            Navigator.of(context).pop();
            // Reopen the dialog with the updated image
            Future.delayed(const Duration(milliseconds: 500), () {
              _showDocumentImage(context, title, imageUrl, id);
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Upload failed: ${responseData['error'] ?? 'Unknown error'}',
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('HTTP ${response.statusCode}: $responseBody'),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
