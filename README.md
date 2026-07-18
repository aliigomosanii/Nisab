# Nisab (نصاب)

An iOS app for calculating gold zakat — a quick calculator plus a Gold
Wallet that tracks your owned gold (weight, karat, purchase date and
price, invoice photos) and computes zakat across it.

**Languages:** Arabic · English · Urdu (full RTL support)

## Zakat rules used

- Nisab: **85 g of pure (24k-equivalent) gold**; purity = karat / 24
- Rate: **2.5%**, shown in grams of gold always, and in currency when a
  price is available
- Hawl: payments exempt an item until the next **Umm al-Qura lunar-year
  anniversary of its purchase date** (paying late doesn't shift the
  cycle); per-item payment history is kept
- Today's 24k price auto-fetched from public feeds (gold-api.com +
  exchangerate-api) with manual override always available

## Architecture

Local-first: all data on-device with SwiftData, no accounts or server.
SwiftUI, iOS 17+.

## Building

The Xcode project is generated (not committed):

```sh
brew install xcodegen   # if needed
xcodegen generate
open Nisab.xcodeproj
```
