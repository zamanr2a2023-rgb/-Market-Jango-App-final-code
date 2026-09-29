import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-wide container so services without a [WidgetRef] can invalidate providers.
final appProviderContainer = ProviderContainer();
