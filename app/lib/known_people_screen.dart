import 'package:flutter/material.dart';
import 'services/local_db_service.dart';
import 'models/known_face.dart';
import 'dart:convert';
import 'add_person_dialog.dart';

class KnownPeopleScreen extends StatefulWidget {
  const KnownPeopleScreen({super.key});

  @override
  State<KnownPeopleScreen> createState() => _KnownPeopleScreenState();
}

class _KnownPeopleScreenState extends State<KnownPeopleScreen> {
  final LocalDbService _localDbService = LocalDbService();
  List<KnownFace> _knownFaces = [];

  @override
  void initState() {
    super.initState();
    _loadKnownFaces();
  }

  void _loadKnownFaces() {
    setState(() {
      _knownFaces = _localDbService.getAllKnownFaces();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Known People', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AddPersonDialog(
                  onPersonAdded: _loadKnownFaces,
                ),
              );
            },
          ),
        ],
      ),
      body: _knownFaces.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.white30),
                  SizedBox(height: 16),
                  Text(
                    "No known people registered yet.",
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 0.85,
              ),
              itemCount: _knownFaces.length,
              itemBuilder: (context, index) {
                final face = _knownFaces[index];
                return Card(
                  color: const Color(0xFF2C2C2C),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.blueAccent.withOpacity(0.2),
                          backgroundImage: face.imageBase64.isNotEmpty 
                              ? MemoryImage(base64Decode(face.imageBase64)) 
                              : null,
                          onBackgroundImageError: (_, __) {},
                          child: face.imageBase64.isEmpty 
                              ? const Icon(Icons.person, color: Colors.white, size: 40)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          face.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          face.role.isNotEmpty ? face.role : 'No role',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
