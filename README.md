# ba_spree

**Run a Japanese storefront on Spree, out of the box.**

Spree Commerce works fine as-is, but selling in Japan means building a lot of
things yourself: address fields in Japanese order, prefectures, tax-inclusive
pricing, bank transfer and cash-on-delivery payments.

ba_spree bundles all of that. It also ships roughly 3,000 Japanese translation
keys, so both the admin and the storefront are in Japanese from the moment you
install it.

Supported Spree version: **5.3.6**

---

## Try it

[ba_spree_starter](https://github.com/be-agile/ba_spree_starter) is a complete,
runnable application.

```bash
git clone https://github.com/be-agile/ba_spree_starter.git
cd ba_spree_starter
bundle install

bin/rails db:migrate
bin/rails db:seed             # country, prefectures, tax, shipping, JPY
bin/rails spree_sample:load   # Japanese sample products and orders

bin/rails server
```

`db:seed` and `spree_sample:load` are two separate commands.
The sample data lives in the latter.

## Add it to an existing app

```ruby
# Gemfile
gem 'ba_spree'
```

```bash
bundle install
bin/rails g ba_spree:install
```

`ba_spree:install` copies the migrations from every bundled engine in one go
(36 migrations across 9 engines). You do not need to run each engine's
generator separately.

To set a store up for Japan, call this from `db/seeds.rb` or similar:

```ruby
BaSpree::SetupService.setup(store: Spree::Store.default)
```

That configures:

- Country Japan, and all 47 prefectures
- A "日本" zone
- Consumption tax at 10% / 8% (reduced rate) / exempt
- A flat-rate shipping method with Sagawa tracking URLs
- JPY currency and `ja` locale

It deliberately does not touch the store name, URL or email addresses — those
are specific to your shop, so set them yourself.

## What you get

ba_spree itself is a thin wrapper. The substance is these 23 engines, all
pulled in by a single `gem 'ba_spree'`.

### Japanese commerce conventions

| gem | What it does |
|---|---|
| `spree_address_format_i18n` | Japanese address format (name order, prefectures, field order) |
| `spree_zip_autocomplete` | Autofill an address from a postal code |
| `ba_spree_bank_transfer` | Bank transfer payments |
| `ba_spree_cash_on_delivery` | Cash on delivery |
| `spree_np_atobarai` | NP deferred payment (admin screens, CSV export, invoice delivery options) |
| `spree_gmo_pg` | GMO Payment Gateway integration |
| `spree_direct_debit` | Direct debit (B2B, processed through the banking system) |
| `spree_custom_email` | Customisable email templates |

### General extensions

| gem | What it does |
|---|---|
| `ba_spree_loyalty_points` | Earning and spending loyalty points |
| `spree_materials` | Image / PDF asset management with shareable links for product descriptions |
| `ba_spree_related_products` | Relate products to each other, with multiple relation types |
| `spree_products_payment_methods` | Restrict payment methods per product |
| `spree_limit_order_quantity` | Minimum and maximum order quantity per product or variant |
| `spree_option_type_description` | Add descriptions to option types and show them on the product page |
| `spree_search_with_description` | Include product descriptions in search |
| `spree_auto_capture_digital` | Auto-capture orders containing only digital products |
| `spree_digital_payment_notice` | Show payment notices for orders containing digital products |
| `spree_checkout_signup_promotion` | Prompt sign-up / login at the checkout address step |
| `spree_order_total_discount` | Percentage discount on the order total |
| `spree_common_shipping_method_splitter` | Ship items in one package when their shipping categories share a shipping method |
| `spree_promotion_action_create_line_items` | Stop customers adding, changing or removing the items a promotion adds to the cart |

### Analytics

| gem | What it does |
|---|---|
| `ba_spree_google_analytics` | Google Analytics tracking (fork of the official Spree gem) |
| `spree_yahoo_ads` | Yahoo! Ads conversion tracking |

## Where behaviour differs from upstream Spree

Some behaviour is changed to suit the Japanese market. We plan to make these
switchable through Spree preferences in future.

| Behaviour | Upstream | ba_spree |
|---|---|---|
| Multiple promotions | Keeps only the best one | Allows them to combine |
| Company name field | Controlled by `Store#prefers_company_field_enabled?` | Always shown |
| Store lookup with no default flag | First record in the database | Returns a new default instance |
| Image variant `preprocessed` | 5.3 default | Can be disabled via an environment variable |
| MetafieldDefinition keys | Run through `parameterize` | Japanese text preserved as-is |
| Cart line item thumbnail | 128px named variant | 60px dynamic variant |

## Requirements

- Ruby >= 3.1.4
- Spree 5.3.6
- Rails 8.x
- MySQL or PostgreSQL

The Spree version is pinned to 5.3.6. From 5.4 onwards the Rails storefront
(`spree_storefront`) moved to a separate repository and stopped receiving
updates at 5.4.6, and ba_spree overrides 30 of its views.

## Licence

AGPL-3.0-or-later. See [LICENSE](LICENSE) for the full text.

ba_spree copies and modifies parts of the Spree 5.3.6 source. Of those,
`spree_storefront` and `spree_admin` 5.3.6 are distributed under
AGPL-3.0-or-later alone, so ba_spree is AGPL too.

Engines that originated as forks retain the original BSD-3-Clause copyright
notice and terms, as clause 1 of that licence requires.

## Development

This repository is a distribution copy of `engines/ba_spree` from
[giga-repeat](https://github.com/be-agile/giga-repeat).
Bug reports and suggestions are welcome in the issue tracker.
