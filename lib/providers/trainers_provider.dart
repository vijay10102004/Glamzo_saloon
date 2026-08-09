import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trainer_model.dart';
import '../models/slot_model.dart';
import 'offers_provider.dart';

final trainersForOfferProvider =
    FutureProvider.family<List<TrainerModel>, List<String>>(
        (ref, ids) =>
            ref.read(firestoreServiceProvider).getTrainersForOffer(ids));

final allTrainersProvider = FutureProvider<List<TrainerModel>>(
    (ref) => ref.read(firestoreServiceProvider).getAllTrainers());

/// Real-time stream of all trainers for the stylist catalogue
final allTrainersStreamProvider = StreamProvider<List<TrainerModel>>(
    (ref) => ref.read(firestoreServiceProvider).getAllTrainersStream());

final selectedTrainerProvider = StateProvider<TrainerModel?>((ref) => null);

final nextSlotProvider = FutureProvider.family<SlotModel?, String>(
    (ref, trainerId) =>
        ref.read(firestoreServiceProvider).getNextAvailableSlot(trainerId));
