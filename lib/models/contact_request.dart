enum ContactRequestStatus {
  pending,
  accepted,
  rejected;

  static ContactRequestStatus parse(String? v) => values.firstWhere(
    (s) => s.name == v,
    orElse: () => ContactRequestStatus.pending,
  );
}

/// A request someone sent to me.
class IncomingRequest {
  const IncomingRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.status,
    this.message,
    this.createdAt,
  });

  final String id;
  final String requesterId;
  final String requesterName;
  final ContactRequestStatus status;
  final String? message;
  final DateTime? createdAt;

  factory IncomingRequest.fromMap(Map<String, dynamic> m) => IncomingRequest(
    id: m['id'] as String,
    requesterId: m['requester_id'] as String,
    requesterName: m['requester_name'] as String? ?? 'Alumni',
    status: ContactRequestStatus.parse(m['status'] as String?),
    message: m['message'] as String?,
    createdAt: m['created_at'] == null
        ? null
        : DateTime.tryParse('${m['created_at']}'),
  );
}

/// A request I sent. It never carries the shared contact: that is fetched
/// separately, and only once accepted.
class OutgoingRequest {
  const OutgoingRequest({
    required this.id,
    required this.targetId,
    required this.targetName,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String targetId;
  final String targetName;
  final ContactRequestStatus status;
  final DateTime? createdAt;

  factory OutgoingRequest.fromMap(Map<String, dynamic> m) => OutgoingRequest(
    id: m['id'] as String,
    targetId: m['target_id'] as String,
    targetName: m['target_name'] as String? ?? 'Alumni',
    status: ContactRequestStatus.parse(m['status'] as String?),
    createdAt: m['created_at'] == null
        ? null
        : DateTime.tryParse('${m['created_at']}'),
  );
}
