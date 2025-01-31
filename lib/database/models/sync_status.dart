import 'package:isar/isar.dart';

part 'sync_status.g.dart';

@collection
class SyncStatus {
  Id id = Isar.autoIncrement;
  
  @Index(type: IndexType.value)
  final int entityId;
  
  @Index(type: IndexType.value)
  final String entityType;
  
  @Index(type: IndexType.value)
  final String operation;
  
  final DateTime timestamp;

  SyncStatus({
    required this.entityId,
    required this.entityType,
    required this.operation,
    required this.timestamp,
  });
}
