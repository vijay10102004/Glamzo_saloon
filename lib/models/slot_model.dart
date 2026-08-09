class SlotModel {
  final String id;
  final String trainerId;
  final DateTime startTime;
  final DateTime endTime;
  final String status; // available / booked / blocked
  final String branch; // 'Anna Nagar' | 'Kaalavasal' | ''

  const SlotModel({
    required this.id,
    required this.trainerId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.branch = '',
  });

  bool get isAvailable => status == 'available';

  factory SlotModel.fromMap(String id, Map<String, dynamic> map) {
    return SlotModel(
      id: id,
      trainerId: map['trainerId'] ?? '',
      startTime: (map['startTime'] as dynamic).toDate(),
      endTime: (map['endTime'] as dynamic).toDate(),
      status: map['status'] ?? 'available',
      branch: map['branch'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'trainerId': trainerId,
    'startTime': startTime,
    'endTime': endTime,
    'status': status,
    'branch': branch,
  };
}
