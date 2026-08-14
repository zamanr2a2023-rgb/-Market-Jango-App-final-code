# Flutter: Buyer Delivery Charge Details

Short guide for the **Delivery charge details** screen.

**GET** `/api/cart/delivery-charges`

**Headers:** same as other buyer APIs (`token` / `Authorization`, `id`, `user_type: buyer`).

All money labels must use `*_display` + `display_currency`. Do not format the raw UGX fields.

---

## Screen mapping

### 1. Delivery charge by route

Loop `data.routes`.

| UI | Property |
|---|---|
| `#` | index + 1 |
| Route title | `route_label` |
| Vendors | `vendor_names` |
| Calculation line | build from `flat_display`, `weight_based_display`, `cube_based_display` |
| Cost | `cost_display` + `display_currency` |

Calculation text (skip any amount that is `0`):

```text
Flat, {flat_display}{display_currency}
+ if weight_based > 0:  , weight {weight_based_display} {display_currency}
+ if cube_based > 0:    , cube {cube_based_display} {display_currency}
```

Example: `Flat, 3000UGX, weight 10 UGX`

If `routes` is empty, show the table empty (or “No delivery route”). Products, fees, and totals still render.

### 2. Extras (products)

Loop `data.line_items`. “Phone” in the design is the **product name**.

| UI | Property |
|---|---|
| Product name | `product_name` |
| weight | `effective_weight_kg` |
| Cube | `effective_cube_m3` (hide if `0`) |

### 3. Fees

From `data.fees`.

| UI | Property |
|---|---|
| Platform fees | `fees.platform_fee_display` |
| tax | `fees.tax_display` |

### 4. Summary

| UI | Property |
|---|---|
| Total (merchandise + delivery + fees) | `cart_total_with_delivery_and_fees_display` |
| Merchandise | `cart_merchandise_subtotal_display` |
| delivery | `cart_total_delivery_charge_display` |
| fees | `fees.total_display` |
| zone weight | `cart_total_weight_kg` + `kg` |
| currency | `display_currency` |

---

## Example `data.routes[]` item

```json
{
  "route_id": 12,
  "route_label": "Masaka to Kampala",
  "from_point": "Masaka",
  "to_point": "Kampala",
  "vendor_names": "Vendor A, Vendor B, Vendor C",
  "vendors": [
    { "vendor_id": 1, "vendor_name": "Vendor A" }
  ],
  "flat": 3000,
  "weight_based": 10,
  "cube_based": 0,
  "cost": 3010,
  "flat_display": 3000,
  "weight_based_display": 10,
  "cube_based_display": 0,
  "cost_display": 3010,
  "weight_kg": 10,
  "cube_m3": 0,
  "delivery_timeline": "2 hours"
}
```

---

## Empty route list

If a line has `skip_reason` (for example `vendor_town_not_configured` or `no_matching_route`), it still appears in `line_items` (extras table) but **not** in `routes`. Delivery cost will be `0` until admin sets vendor visibility town and a matching route.

---

## Dart sketch

```dart
final data = json['data'] as Map<String, dynamic>;
final currency = data['display_currency'] as String; // e.g. UGX
final routes = (data['routes'] as List?) ?? [];
final items = (data['line_items'] as List?) ?? [];
final fees = data['fees'] as Map<String, dynamic>;

String money(dynamic value) => '$value$currency';

String calculation(Map route) {
  final parts = <String>['Flat, ${money(route['flat_display'])}'];
  if ((route['weight_based'] as num? ?? 0) > 0) {
    parts.add('weight ${money(route['weight_based_display'])}');
  }
  if ((route['cube_based'] as num? ?? 0) > 0) {
    parts.add('cube ${money(route['cube_based_display'])}');
  }
  return parts.join(', ');
}
```
