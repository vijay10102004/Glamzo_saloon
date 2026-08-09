import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/slot_model.dart';
import 'offers_provider.dart';

final selectedDateProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

final selectedSlotProvider = StateProvider<SlotModel?>((ref) => null);

/// All slots (available + booked) for the slot picker — shows booked as greyed out.
/// Filters by [branch] so Anna Nagar and Kaalavasal have separate slot pools.
final allSlotsProvider = StreamProvider.family<List<SlotModel>,
    ({String trainerId, DateTime date, String branch})>((ref, params) {
  return ref
      .read(firestoreServiceProvider)
      .getAllSlots(params.trainerId, params.date, branch: params.branch);
});

/// Only available slots (legacy / for quick-checks).
/// Filters by [branch] so Anna Nagar and Kaalavasal have separate slot pools.
final slotsProvider = StreamProvider.family<List<SlotModel>,
    ({String trainerId, DateTime date, String branch})>((ref, params) {
  return ref
      .read(firestoreServiceProvider)
      .getAllSlots(params.trainerId, params.date, branch: params.branch)
      .map((slots) =>
          slots.where((s) => s.status == 'available').toList());
});
