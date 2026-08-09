import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_model.dart';
import '../models/trainer_model.dart';
import 'offers_provider.dart';
import 'trainers_provider.dart';

/// Current search query typed by the user
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Active price range filter: [min, max]
final priceRangeProvider = StateProvider<RangeValues>((ref) => const RangeValues(0, 5000));

/// Selected category filter chips (empty = all)
final selectedCategoriesProvider = StateProvider<Set<String>>((ref) => {});

/// Filtered services based on query + price + category
final filteredServicesProvider = Provider<AsyncValue<List<ServiceModel>>>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final priceRange = ref.watch(priceRangeProvider);
  final selectedCategories = ref.watch(selectedCategoriesProvider);
  final servicesAsync = ref.watch(servicesProvider);

  return servicesAsync.when(
    data: (services) {
      var filtered = services.where((s) {
        final matchQuery = query.isEmpty ||
            s.name.toLowerCase().contains(query) ||
            s.category.toLowerCase().contains(query) ||
            s.description.toLowerCase().contains(query);
        final matchPrice = s.price >= priceRange.start && s.price <= priceRange.end;
        final matchCategory =
            selectedCategories.isEmpty || selectedCategories.contains(s.category);
        return matchQuery && matchPrice && matchCategory;
      }).toList();
      return AsyncData(filtered);
    },
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
  );
});

/// Filtered trainers based on query only
final filteredTrainersProvider = Provider<AsyncValue<List<TrainerModel>>>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final trainersAsync = ref.watch(allTrainersStreamProvider);

  return trainersAsync.when(
    data: (trainers) {
      if (query.isEmpty) return const AsyncData([]);
      final filtered = trainers.where((t) {
        return t.name.toLowerCase().contains(query) ||
            t.specialties.any((s) => s.toLowerCase().contains(query));
      }).toList();
      return AsyncData(filtered);
    },
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
  );
});

/// All distinct service categories (for filter chips)
final serviceCategoriesProvider = Provider<List<String>>((ref) {
  final servicesAsync = ref.watch(servicesProvider);
  return servicesAsync.when(
    data: (services) {
      final cats = services.map((s) => s.category).toSet().toList();
      cats.sort();
      return cats;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

