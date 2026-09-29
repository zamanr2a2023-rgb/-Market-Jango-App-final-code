# Flutter — LAST EDITES: Vendor & Driver register

Vendor address uses **Zone → State → Town** dropdowns plus street `address`. Driver uses **number_plate** (not car model) and required zone/state/town.

Postman: [`docs/postman/LAST_EDITES_register.json`](postman/LAST_EDITES_register.json)

---

## Auth headers

| Header | Value |
|--------|--------|
| `token` | JWT after OTP / password step |
| `id` | new user id |
| `user_type` | `vendor` or `driver` |

Dropdown lists (public):

| Step | Path |
|------|------|
| Zones | `GET /api/buyer/visibility-locations/zones` |
| States | `GET /api/buyer/visibility-locations/states?zone=...` |
| Towns | `GET /api/buyer/visibility-locations/towns?zone=...&state=...` |

---

## Screen flow — Vendor

```text
Vendor sign-up → business details
        ↓
Dropdowns: Zone → State → Town
Free text: address (street / building)
        ↓
POST /api/vendor/register
  zone, state, town, address (all required)
        ↓
Done
```

---

## Screen flow — Driver

```text
Driver sign-up → vehicle details
        ↓
Field: number_plate (replace car_model UI)
Dropdowns: Zone → State → Town (required)
        ↓
POST /api/driver/register
  number_plate, zone, state, town, car_name, transport_type, price, ...
        ↓
Done
```

---

## APIs

| UI action | Method | Path |
|-----------|--------|------|
| Vendor register | `POST` | `/api/vendor/register` |
| Driver register | `POST` | `/api/driver/register` |
| Zone list | `GET` | `/api/buyer/visibility-locations/zones` |
| State list | `GET` | `/api/buyer/visibility-locations/states` |
| Town list | `GET` | `/api/buyer/visibility-locations/towns` |

---

## Vendor body

```json
{
  "country": "Uganda",
  "business_name": "Fresh Mart",
  "business_type_ids": [1],
  "zone": "LA",
  "state": "Central",
  "town": "Kampala",
  "address": "Plot 12, Market Street"
}
```

| Field | Required |
|-------|----------|
| `zone`, `state`, `town` | yes (dropdown values) |
| `address` | yes (street / building free text) |
| `business_name`, `country` | yes |
| `business_type_ids` | ≥1 |

---

## Driver body

```json
{
  "car_name": "Toyota Hiace",
  "number_plate": "UBA 123A",
  "zone": "LA",
  "state": "Central",
  "town": "Kampala",
  "transport_type": "car",
  "price": "5000"
}
```

| Field | Required | Notes |
|-------|----------|--------|
| `number_plate` | yes | UI label — **not** car model |
| `car_model` | no | legacy only; do not show |
| `zone`, `state`, `town` | yes | dropdowns |
| `location` | no | auto-built from town, state, zone if omitted |
| `car_name`, `transport_type`, `price` | yes | |

`transport_type`: `car` | `motorcycle` | `air` | `water`.

---

## Flutter checklist

1. Vendor: cascaded Zone → State → Town + street field below.
2. Driver: remove car model input; bind `number_plate`.
3. Driver location = same visibility dropdowns as vendor (required).
4. Send exact dropdown strings in `zone` / `state` / `town`.

---

## Errors to expect

| HTTP | When |
|------|------|
| 422 | Missing zone/state/town/address or number_plate |
| 404 | User not found for header `id` |

---

## Do / Do not

| Do | Do not |
|----|--------|
| Use visibility-location dropdowns | Free-text only for zone/state/town |
| Keep street `address` under dropdowns (vendor) | Drop street field entirely |
| Collect `number_plate` for driver | Show / require `car_model` |
