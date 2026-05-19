import 'package:flutter/material.dart';
import 'aws_sender.dart';
import 'models/known_face.dart';
import 'services/local_db_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final String imageUrl;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    required this.imageUrl,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isFormVisible = false;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  String? _base64Image;
  bool _isApproved = false;
  String? _approvedName;

  @override
  void initState() {
    super.initState();
    _downloadAndInitializeEvent();
  }

  Future<void> _downloadAndInitializeEvent() async {
    try {
      final localDb = LocalDbService();
      final event = localDb.getSecurityEvent(widget.eventId);

      if (event != null && event.status == 'known') {
        final face = localDb.getKnownFace(widget.eventId);
        if (mounted) {
          setState(() {
            _isApproved = true;
            _approvedName = face?.name ?? "Known Person";
            _base64Image = event.imageBase64;
          });
        }
        return;
      }

      if (event == null || event.imageBase64 == null) {
        final response = await http.get(Uri.parse(widget.imageUrl));
        if (response.statusCode == 200) {
          final base64String = base64Encode(response.bodyBytes);
          if (mounted) {
            setState(() {
              _base64Image = base64String;
            });
          }

          if (event != null) {
            event.status = 'unverified';
            event.imageBase64 = base64String;
            await event.save();
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _base64Image = event.imageBase64;
          });
        }
      }
    } catch (e) {
      print("Failed to download image: $e");
    }
  }

  void _onUnknownPressed() {
    Navigator.of(context).pop();
  }

  void _onKnownPressed() {
    setState(() {
      _isFormVisible = true;
    });
  }

  void _onSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Processing Data...')));

      bool success = await approveUnknownUser(
        widget.eventId,
        _nameController.text.trim(),
        _roleController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        final localDb = LocalDbService();

        final event = localDb.getSecurityEvent(widget.eventId);
        if (event != null) {
          event.status = 'known';
          await event.save();
        }

        final newKnownFace = KnownFace(
          faceId: widget.eventId,
          name: _nameController.text.trim(),
          role: _roleController.text.trim(),
          imageBase64: _base64Image ?? '',
        );
        await localDb.addKnownFace(newKnownFace);

        setState(() {
          _isApproved = true;
          _approvedName = _nameController.text.trim();
          _isFormVisible = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully registered known person!'),
            backgroundColor: Colors.green,
          ),
        );
        //Navigator.of(context).pop(); // Go back after success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit data. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showImageFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          extendBodyBehindAppBar: true,
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: _base64Image != null
                  ? Image.memory(
                      base64Decode(_base64Image!),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : const CircularProgressIndicator(color: Colors.blueAccent),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark theme background
      appBar: AppBar(
        title: Text(
          _isApproved
              ? (_approvedName ?? 'Known Person')
              : 'Event Details: ${widget.eventId}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Display Section
            Container(
              height: 300,
              width: double.infinity,
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.blueAccent.withOpacity(0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: _showImageFullScreen,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _base64Image != null
                      ? Image.memory(
                          base64Decode(_base64Image!),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[900],
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.redAccent,
                                  size: 50,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[900],
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_isApproved)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.greenAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Approved: $_approvedName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Action Buttons
            if (!_isApproved)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _onKnownPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text(
                          'Known',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _onUnknownPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.warning_amber_rounded),
                        label: const Text(
                          'Unknown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Form Section
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isFormVisible
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Register Known Person',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Name TextField
                              TextFormField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Name',
                                  labelStyle: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.person,
                                    color: Colors.grey,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF2C2C2C),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                  errorStyle: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Name is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Role TextField
                              TextFormField(
                                controller: _roleController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Role (Optional)',
                                  labelStyle: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.work,
                                    color: Colors.grey,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF2C2C2C),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Submit Button
                              ElevatedButton(
                                onPressed: _onSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Submit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
