import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/message.dart';

class LocalChatService {
  // Gets the local path for storing chat files
  Future<String> _getLocalPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Creates a file reference for a specific chat room
  Future<File> _getChatFile(String roomId) async {
    final path = await _getLocalPath();
    // Using a confusing name or hidden folder could add 'protection',
    // but here we stick to the user's request of "protected file"
    // We will name it with a prefix that indicates it's internal data.
    return File('$path/secure_chat_data_$roomId.dat');
  }

  // Save messages to local storage
  Future<void> saveMessages(String roomId, List<Message> messages) async {
    try {
      final file = await _getChatFile(roomId);

      // Convert messages to a list of maps
      // We need to handle DateTime and other non-JSON types here if Message.toMap doesn't clean them for JSON.
      // Message.toMap uses Timestamp, which is not JSON serializable directly.
      // We will create a custom JSON-friendly list.
      final List<Map<String, dynamic>> jsonList = messages.map((msg) {
        final map = msg.toMap();
        // Convert Firestore Timestamp to ISO string for JSON storage
        // If msg.toMap returns Timestamp object for 'timestamp' field:
        if (map['timestamp'] != null) {
          // It might be a Timestamp object from cloud_firestore
          try {
            // Assuming it has .toDate() or similar.
            // Actually Message.toMap() creates a Timestamp.
            // We need to convert it to something JSON safe.
            dynamic ts = map['timestamp'];
            if (ts.toString().contains("Timestamp")) {
              // It's likely a cloud_firestore Timestamp
              map['timestamp'] = ts.toDate().toIso8601String();
            } else if (ts is DateTime) {
              map['timestamp'] = ts.toIso8601String();
            }
          } catch (e) {
            map['timestamp'] = DateTime.now().toIso8601String();
          }
        }
        return map;
      }).toList();

      final jsonString = jsonEncode(jsonList);

      // Simple "Protection" / Obfuscation as requested: Base64 Encode
      // This makes the file unreadable as plain text.
      final encodedContent = base64Encode(utf8.encode(jsonString));

      await file.writeAsString(encodedContent);
    } catch (e) {
      print('Error saving local messages: $e');
    }
  }

  // Load messages from local storage
  Future<List<Message>> loadMessages(String roomId) async {
    try {
      final file = await _getChatFile(roomId);

      if (!await file.exists()) {
        return [];
      }

      final encodedContent = await file.readAsString();

      if (encodedContent.isEmpty) return [];

      // Decode Base64
      final jsonString = utf8.decode(base64Decode(encodedContent));
      final List<dynamic> jsonList = jsonDecode(jsonString);

      return jsonList.map((map) {
        // Convert ISO string back to Timestamp for Message.fromMap
        // Message.fromMap expects 'timestamp' to be a Timestamp object usually,
        // or we need to adjust logic there.
        // However, looking at Message.fromMap in the codebase:
        // timestamp: (map['timestamp'] as Timestamp).toDate()
        // It strictly casts to Timestamp. We might need to adjust Message.fromMap
        // OR mock a Timestamp here.

        // Better approach: Modify the map to have what Message.fromMap expects,
        // BUT Message.fromMap is tightly coupled to Firestore.
        // Let's rely on the robust fix we added earlier:
        // timestamp: ts?.toDate() ?? DateTime.now(),
        // where ts = map['timestamp'] as Timestamp?;

        // If we pass an ISO string, 'as Timestamp?' will fail or return null?
        // Iterate: 'as' throws if type doesn't match.

        // We need to handle this. Since we can't easily create valid Firestore Timestamps
        // from pure JSON without the library being involved in a specific way,
        // let's pass a custom map to Message.fromMap or simpler:
        // modifying Message.fromMap to handle String/DateTime is strictly better.

        // For now, let's revive it as a Timestamp if we can, or modify Message.fromMap.
        // I will modify Message.fromMap to handle String/int timestamps too.

        return Message.fromMap(map['id'] ?? 'unknown', map);
      }).toList();
    } catch (e) {
      print('Error loading local messages: $e');
      return [];
    }
  }

  // Append or Update a single message
  Future<void> saveMessage(
    String userId,
    String roomId,
    Map<String, dynamic> messageMap,
  ) async {
    final messages = await loadMessages(roomId);
    final index = messages.indexWhere((m) => m.id == messageMap['id']);

    final newMessage = Message.fromMap(messageMap['id'], messageMap);

    if (index >= 0) {
      messages[index] = newMessage;
    } else {
      messages.add(newMessage);
    }
    await saveMessages(roomId, messages);
  }

  // Update specific fields of a message
  Future<void> updateMessage(
    String roomId,
    String messageId,
    Map<String, dynamic> updates,
  ) async {
    final messages = await loadMessages(roomId);
    final index = messages.indexWhere((m) => m.id == messageId);

    if (index >= 0) {
      final oldMsg = messages[index];
      final oldMap = oldMsg.toMap();

      // Apply updates (excluding non-serializable fields if any, checking types)
      updates.forEach((key, value) {
        oldMap[key] = value;
      });

      // Re-create message
      // Note: Message.fromMap handles Timestamp/String conversions.
      // But oldMap['timestamp'] from toMap() is Timestamp.
      // Updates might have new timestamp? Probably not for edit.
      messages[index] = Message.fromMap(messageId, oldMap);

      await saveMessages(roomId, messages);
    }
  }
}
