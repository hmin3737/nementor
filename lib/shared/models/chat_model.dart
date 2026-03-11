import 'package:equatable/equatable.dart';

enum MessageType { text, image, math, system }

class ChatRoom extends Equatable {
  const ChatRoom({
    required this.id,
    required this.questionId,
    required this.studentId,
    required this.mentorId,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageAt,
  });

  final String id;
  final String questionId;
  final String studentId;
  final String mentorId;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
        id: json['id'] as String,
        questionId: json['question_id'] as String,
        studentId: json['student_id'] as String,
        mentorId: json['mentor_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        lastMessage: json['last_message'] as String?,
        lastMessageAt: json['last_message_at'] != null
            ? DateTime.parse(json['last_message_at'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, questionId];
}

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.type,
    this.text,
    this.imageUrl,
    this.mathExpression,
    required this.createdAt,
    this.isMe = false,
  });

  final String id;
  final String roomId;
  final String senderId;
  final MessageType type;
  final String? text;
  final String? imageUrl;
  final String? mathExpression;
  final DateTime createdAt;
  final bool isMe;

  factory ChatMessage.fromJson(Map<String, dynamic> json,
      {String? currentUserId}) {
    final senderId = json['sender_id'] as String;
    return ChatMessage(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: senderId,
      type: MessageType.values.firstWhere(
        (t) => t.name == (json['type'] as String? ?? 'text'),
        orElse: () => MessageType.text,
      ),
      text: json['text'] as String?,
      imageUrl: json['image_url'] as String?,
      mathExpression: json['math_expression'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isMe: currentUserId != null && senderId == currentUserId,
    );
  }

  @override
  List<Object?> get props => [id, roomId, senderId, createdAt];
}
