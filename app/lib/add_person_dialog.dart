import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'aws_sender.dart';
import 'models/known_face.dart';
import 'services/local_db_service.dart';

class AddPersonDialog extends StatefulWidget {
  final VoidCallback onPersonAdded;

  const AddPersonDialog({super.key, required this.onPersonAdded});

  @override
  State<AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<AddPersonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();

  String? _base64Image;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _base64Image = base64Encode(bytes);
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_base64Image == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an image.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final name = _nameController.text.trim();
      final role = _roleController.text.trim();

      // Check if user with the exact same name already exists (case-insensitive)
      final localDb = LocalDbService();
      final nameExists = localDb.getAllKnownFaces().any(
        (face) => face.name.trim().toLowerCase() == name.toLowerCase(),
      );

      if (nameExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A person with this name is already saved. Please choose a different name.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      // Send to AWS
      final success = await addKnownPerson(name, role, _base64Image!);

      if (success) {
        // Generate a new ID and save locally
        final faceId = const Uuid().v4();
        final newFace = KnownFace(
          faceId: faceId,
          name: name,
          role: role,
          imageBase64: _base64Image!,
        );
        await localDb.addKnownFace(newFace);

        if (mounted) {
          widget.onPersonAdded();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Person added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add person to server.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Known Person',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blueAccent.withOpacity(0.2),
                  backgroundImage: _base64Image != null
                      ? MemoryImage(base64Decode(_base64Image!))
                      : null,
                  child: _base64Image == null
                      ? const Icon(
                          Icons.add_a_photo,
                          color: Colors.white,
                          size: 40,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF2C2C2C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Role (Optional)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF2C2C2C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.blueAccent,
                            strokeWidth: 2,
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
