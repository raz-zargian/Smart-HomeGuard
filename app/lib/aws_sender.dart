import 'dart:convert';
import 'package:http/http.dart' as http;

Future<bool> approveUnknownUser(
  String eventId,
  String name,
  String role,
) async {
  // The API Gateway endpoint matching your lambdaApproveUnknownUser setup
  final String apiUrl =
      'https://0vqf7cd4q5.execute-api.us-east-1.amazonaws.com/approve/upload/approve';

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

    print('Raw response status: ${response.statusCode}');
    print('Raw response body: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      // Handle case where API Gateway does NOT use Lambda Proxy Integration
      Map<String, dynamic> actualData = responseData;
      int innerStatusCode = response.statusCode;

      if (responseData.containsKey('statusCode')) {
        innerStatusCode = responseData['statusCode'] is String
            ? int.tryParse(responseData['statusCode']) ?? innerStatusCode
            : responseData['statusCode'];
      }

      if (responseData.containsKey('body') && responseData['body'] is String) {
        actualData = jsonDecode(responseData['body']);
      }

      if (innerStatusCode == 200) {
        print('Success: ${actualData['message']}');
        return true;
      } else {
        print(
          'Error from Lambda: $innerStatusCode - ${actualData['error'] ?? actualData}',
        );
        return false;
      }
    } else {
      print('Failed to approve user. HTTP Status: ${response.statusCode}');
      return false;
    }
  } catch (e) {
    print('Error making API request: $e');
    return false;
  }
}
