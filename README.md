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

Done: auth for both roles, restaurant browse + search, menu, cart, rider dashboard with shift toggle,
location pings and accept/decline/complete.

Next: checkout (delivery quote, cash + Paystack), order history and live tracking, rider socket
(`NEW_DELIVERY_REQUEST`) instead of polling, earnings and wallet, push notifications, chat, fonts
(Inter + Baloo 2) and the web's brand polish.
