import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/navigation_drawer.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.file_copy_rounded,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'BIR Certificate of Registration 2025',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => _showDocumentImage(
                      context,
                      'BIR Certificate of Registration 2025',
                      'https://www.taxumo.com/wp-content/uploads/2025/01/Title-Page-2-2.png',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.file_copy_rounded,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'SEC Articles of Incorporation',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => _showDocumentImage(
                      context,
                      'SEC Articles of Incorporation',
                      'https://www.kmbi.org.ph/images/KMBI-Articles-of-Incorporation_Page_1.jpg',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.file_copy_rounded,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'DTI Business Name Renewal',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => _showDocumentImage(
                      context,
                      'DTI Business Name Renewal',
                      'https://www.pdffiller.com/preview/30/608/30608888/large.png',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.file_copy_rounded,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'Employee Contract',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => _showDocumentImage(
                      context,
                      'Employee Contract',
                      'https://imgv2-2-f.scribdassets.com/img/document/394115455/original/da167a9b76/1?v=1',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.file_copy_rounded,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'January 2025 Financial Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => _showDocumentImage(
                      context,
                      'January 2025 Financial Report',
                      'https://amplify.business/wp-content/smush-webp/2025/03/Hot_Sauce_Example_Report___Hot_Sauce_Example__Jan_2025___2_-images-8-scaled.jpg.webp',
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
                  'Categories',
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
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.file_copy_rounded,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'BIR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.file_copy_rounded,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'SEC',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.file_copy_rounded,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'DTI',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.file_copy_rounded,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      "Mayor's Permit",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.file_copy_rounded,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      "Employee Records",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.file_copy_rounded,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      "Accounting",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.file_copy_rounded,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      "Operations",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.file_copy_rounded,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      "Others",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showDocumentImage(
    BuildContext context,
    String title,
    String imageUrl,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            height: 500,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1e293b),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
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
                        return const Center(
                          child: Text('Failed to load image'),
                        );
                      },
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
}
