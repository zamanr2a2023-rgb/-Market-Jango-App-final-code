class AppTranslations {
  final Map<String, String> _values;

  AppTranslations(this._values);

  /// Built-in English labels when API translations are missing (guest / offline).
  static const Map<String, String> englishFallbacks = {
    'search_product': 'Search products',
    'categories': 'Categories',
    'see_all': 'See all',
    'top_products': 'Top products',
    'new_items': 'New items',
    'just_for_you': 'Just for you',
    'home': 'Home',
    'chat': 'Chat',
    'cart': 'Cart',
    'my_profile': 'My profile',
    'loading': 'Loading...',
    'something_went_wrong': 'Something went wrong',
    'no_top_products': 'No top products',
    'please_add_the_cart_product': 'Please add a product to the cart',
    'shippingAddress': 'Shipping address',
    'shipping_address': 'Shipping address',
    'payment': 'Payment',
    'contactInformation': 'Contact information',
    'buyNow': 'Buy now',
    'buy_now': 'Buy now',
    'all_categories': 'All categories',
    'filter_products': 'Filter products',
    'myOrders': 'My orders',
    'my_orders': 'My orders',
    'orderHistory': 'Order history',
    'order_history': 'Order history',
    'wallet': 'Wallet',
    'settings': 'Settings',
    'updating': 'Updating...',
    'review': 'Review',
    'no_popular_products_found': 'No popular products found',
  };

  factory AppTranslations.fromJson(Map<String, dynamic> json) {
    final map = <String, String>{};
    json.forEach((key, value) {
      map[key] = value?.toString() ?? '';
    });
    return AppTranslations(map);
  }

  /// Empty map still resolves English fallbacks via [get].
  factory AppTranslations.empty() => AppTranslations(const {});

  /// API value → explicit fallback → English map → humanized key.
  String get(String key, {String? fallback}) {
    final v = _values[key];
    if (v != null && v.isNotEmpty) return v;
    if (fallback != null && fallback.isNotEmpty) return fallback;
    final en = englishFallbacks[key];
    if (en != null && en.isNotEmpty) return en;
    return _humanizeKey(key);
  }

  static String _humanizeKey(String key) {
    final parts = key.split('_').where((p) => p.isNotEmpty);
    return parts
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String operator [](String key) => get(key);
}
