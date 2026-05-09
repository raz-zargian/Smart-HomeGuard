import 'dart:convert';
import 'package:http/http.dart' as http;

Future<bool> approveUnknownUser(
  String eventId,
  String name,
  String role,
) async {
  // The API Gateway endpoint matching your lambdaApproveUnknownUser setup
  final String apiUrl =
      'https://0vqf7cd4q5.execute-api.us-east-1.amazonaws.com/approve';

  try {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'event_id': eventId,
        'user_name': name,
        'user_role': role.isEmpty
            ? 'Undefined'
            : role, // Defaults to Undefined if empty
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      print('Success: ${responseData['message']}');
      return true;
    } else {
      print('Failed to approve user: ${response.statusCode}');
      return false;
    }
  } catch (e) {
    print('Error making API request: $e');
    return false;
  }
}
