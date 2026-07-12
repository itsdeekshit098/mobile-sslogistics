import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/location_repository.dart';

final locationRepositoryProvider =
    Provider<LocationRepository>((ref) => LocationRepository());
