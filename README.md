# OyaEat mobile

Flutter app for **customers** and **riders** of OyaEat, a food-delivery platform for Nigeria.
One app, two roles: you pick Customer or Rider on the login screen.

Talks to the OyaEat backend (`oyaeat_backend`, Express + Prisma + Socket.IO).

## Run

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000   # Android emulator -> host machine
```

`API_BASE_URL` defaults to `http://10.0.2.2:5000`. On a real device use your machine's LAN address
or the deployed API.

```bash
flutter analyze
flutter test
```

## Structure

```
lib/
  core/        config, theme, HTTP client, secure storage, router
  features/
    auth/      login, customer signup, rider registration, session
    customer/  restaurants, menu, cart
    rider/     dashboard, shift toggle, location pings, accept/decline/complete
  shared/      shared widgets (shells, profile, async states)
```

State management is [Riverpod](https://riverpod.dev); routing is `go_router`, which sends each role to its own
half of the app (`/c/...` customer, `/r/...` rider).

## Backend quirks handled in the client

Most routes reply `{success, data, message}`, but rider login, `GET /rider/dashboard` and
`GET /orders/:id/track-rider` return their payload at the top level; `ApiClient.unwrap` hides that.
The rider dashboard returns display strings (`id: "ORD-12"`, `payout: "₦1,200"`), which are kept as-is.

## Status

**Customer** (all against the existing backend, no backend changes needed):
sign up / log in, browse and search restaurants, cuisine filters, promo carousel, favourites,
menu with category tabs and add-to-cart sheet, cart (single restaurant, minimum-order rule),
checkout (saved or pinned address, live delivery-fee quote, cash or Paystack), payment confirmation,
order history, order tracking with progress timeline, rider details and distance, cancel, review,
saved addresses.

**Sign-in:** one login for everyone; the app works out whether the account is a customer or a rider
(the role is only chosen when signing up). Animated splash, forgot-password by email link.

**Rider:** register (ID upload), dashboard, online/offline shift, location pings,
accept / decline / complete deliveries.

Next: rider socket (`NEW_DELIVERY_REQUEST`) instead of polling, rider earnings and wallet,
push notifications (needs a small backend addition), chat/support, map view for tracking.

## Notes

- Fonts (Inter, Baloo 2) are fetched by `google_fonts` the first time the app runs online and cached.
- Paystack opens in an in-app web view; the redirect is intercepted and the payment is then
  confirmed with the server (`/orders/verify-payment/:reference`), never trusted from the redirect.
- The delivery fee shown at checkout is the server's quote; the server prices the order itself.
- `test/fonts` holds Roboto for widget tests only.
