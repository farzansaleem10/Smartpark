import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/parking.dart';
import '../../services/api_service.dart';

class EditParkingScreen extends StatefulWidget {
  final Parking parking;

  const EditParkingScreen({
    super.key,
    required this.parking,
  });

  @override
  State<EditParkingScreen> createState() => _EditParkingScreenState();
}

class _EditParkingScreenState extends State<EditParkingScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _totalSlotsController;
  late TextEditingController _pricePerHourController;

  String? _licenseDocumentPath;
  String? _licenseDocumentName;
  String? _previousLicenseDocument;
  String? _previousDocumentName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.parking.name);
    _descriptionController =
        TextEditingController(text: widget.parking.description ?? '');
    _totalSlotsController =
        TextEditingController(text: widget.parking.totalSlots.toString());
    _pricePerHourController =
        TextEditingController(text: widget.parking.pricePerHour.toString());
    
    // Load previous document if exists
    if (widget.parking.licenseDocument != null && 
        widget.parking.licenseDocument!.isNotEmpty) {
      _previousLicenseDocument = widget.parking.licenseDocument;
      _previousDocumentName = _extractFileName(widget.parking.licenseDocument!);
    }
  }

  String _extractFileName(String path) {
    if (path.isEmpty) return 'Unknown document';
    return path.split('/').last.split('\\').last;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _totalSlotsController.dispose();
    _pricePerHourController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          _licenseDocumentPath = result.files.single.path;
          _licenseDocumentName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick document'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearNewDocument() {
    setState(() {
      _licenseDocumentPath = null;
      _licenseDocumentName = null;
    });
  }

  void _clearPreviousDocument() {
    setState(() {
      _previousLicenseDocument = null;
      _previousDocumentName = null;
    });
  }

  // Helper to open documents safely - same as admin dashboard
  Future<void> _openDocument(String? docPath) async {
    if (docPath == null || docPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No document available"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String fullUrl;
    if (docPath.startsWith('data:')) {
      fullUrl = docPath;
    } else if (docPath.startsWith('http')) {
      fullUrl = docPath;
    } else {
      final cleanBase = ApiService.baseUrl
          .replaceAll('/api', '')
          .replaceAll(RegExp(r'/$'), '');
      final cleanDoc = docPath.startsWith('/') ? docPath : '/$docPath';
      fullUrl = '$cleanBase$cleanDoc';
    }

    final Uri url = Uri.parse(fullUrl);
    debugPrint("🔗 ATTEMPTING TO OPEN: $fullUrl");

    try {
      await launchUrl(
        url,
        mode: fullUrl.contains('10.0.2.2')
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
    } catch (e) {
      debugPrint("🚨 Launch Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not open document."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final payload = <String, dynamic>{};

      final name = _nameController.text.trim();
      if (name.isNotEmpty) payload['name'] = name;

      final description = _descriptionController.text.trim();
      if (description.isNotEmpty) payload['description'] = description;

      final totalSlotsText = _totalSlotsController.text.trim();
      if (totalSlotsText.isNotEmpty) {
        payload['totalSlots'] = int.tryParse(totalSlotsText) ?? widget.parking.totalSlots;
      }

      final priceText = _pricePerHourController.text.trim();
      if (priceText.isNotEmpty) {
        payload['pricePerHour'] = double.tryParse(priceText) ?? widget.parking.pricePerHour;
      }

      // Include new document if selected, otherwise keep previous if not cleared
      if (_licenseDocumentPath != null) {
        payload['licenseDocument'] = _licenseDocumentPath;
      } else if (_previousLicenseDocument != null) {
        payload['licenseDocument'] = _previousLicenseDocument;
      }

      final response = await ApiService.updateParking(
        widget.parking.id,
        payload,
      );

      if (response['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Parking space updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to update parking'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Parking Space'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Parking Name',
                  prefixIcon: Icon(Icons.local_parking),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _totalSlotsController,
                decoration: const InputDecoration(
                  labelText: 'Total Slots',
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pricePerHourController,
                decoration: const InputDecoration(
                  labelText: 'Price Per Hour (₹)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              Text(
                'Verification Document',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              // Previously Uploaded Document Section
              if (_previousLicenseDocument != null && _previousDocumentName != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _openDocument(_previousLicenseDocument),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.insert_drive_file, 
                                    color: Colors.blue.shade600, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'View License Document',
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, 
                                color: Colors.red.shade600, size: 20),
                              onPressed: _clearPreviousDocument,
                              tooltip: 'Remove this document',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              // New Document Upload Section
              if (_previousLicenseDocument == null || _previousDocumentName == null)
                Text(
                  'Upload Document',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                ),
              if (_previousLicenseDocument != null && _previousDocumentName != null)
                Text(
                  'Replace Document',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDocument,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _licenseDocumentPath == null 
                        ? Colors.grey.shade50 
                        : Colors.green.shade50,
                    border: Border.all(
                      color: _licenseDocumentPath == null
                          ? Colors.grey.shade300
                          : Colors.green.shade300,
                      width: _licenseDocumentPath == null ? 1 : 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              _licenseDocumentPath == null
                                  ? Icons.cloud_upload_outlined
                                  : Icons.check_circle,
                              color: _licenseDocumentPath == null
                                  ? Colors.grey.shade600
                                  : Colors.green.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _licenseDocumentName ?? 'Select PDF, JPG, or PNG',
                                style: TextStyle(
                                  color: _licenseDocumentPath == null
                                      ? Colors.grey.shade700
                                      : Colors.green.shade800,
                                  fontWeight: _licenseDocumentPath == null
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_licenseDocumentPath != null)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red, size: 20),
                          onPressed: _clearNewDocument,
                          tooltip: 'Remove selected document',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update Parking Space'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}