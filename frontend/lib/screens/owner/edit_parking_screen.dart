import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

      if (_licenseDocumentPath != null) {
        payload['licenseDocument'] = _licenseDocumentPath;
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
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: _licenseDocumentPath == null
                        ? Colors.grey.shade400
                        : Colors.green,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Icon(
                    _licenseDocumentPath == null
                        ? Icons.upload_file
                        : Icons.check_circle,
                    color: _licenseDocumentPath == null
                        ? Colors.grey
                        : Colors.green,
                  ),
                  title: Text(
                    _licenseDocumentName ?? 'Upload License / Ownership Proof',
                    style: TextStyle(
                      color: _licenseDocumentPath == null
                          ? Colors.grey.shade700
                          : Colors.black,
                      fontWeight: _licenseDocumentPath == null
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text('PDF, JPG, or PNG formats'),
                  trailing: _licenseDocumentPath != null
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _licenseDocumentPath = null;
                              _licenseDocumentName = null;
                            });
                          },
                        )
                      : const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _pickDocument,
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