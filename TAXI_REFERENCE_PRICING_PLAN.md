# Taxi Reference Pricing Plan

## Safe acquisition

Allowed inputs are owner-entered observations, consented field observations,
authorized partner/API feeds, and validated imports. TajGo must not depend on bypassing
access controls, reverse engineering private APIs, impersonating clients or
unauthorized scraping of Maxim or any other provider.

The implemented source contract supports `ExistingDatabaseTaxiPriceProvider`, manual
observations and a future authorized API provider. No Maxim API/scraper is connected.
The customer UI never names a taxi provider or exposes raw market prices.

## Observation model

Collection/domain fields: `cityId`, provider, normalized pickup/dropoff buckets,
distance, duration, quoted price, `TJS`, observation time, local weekday/hour,
source type and quality. It stores no UID, phone, address text or other unnecessary
personal data.

## Reference selection

Selection is city-isolated, filters broadly similar distance/duration, rejects
per-distance outliers, then weights recency, local hour/day, zone match and quality.
At least three samples are required. Insufficient data returns no market reference;
the quote uses the city fallback profile and low-confidence metadata. It never claims
to be a current Maxim price without supporting authorized observations.

## Existing data and next step

Repository/code inspection found the existing TajGo delivery fallback (`7 + 3/km`,
minimum 10 TJS) and marketplace price imports, but no populated historical taxi-price
collection in source. Those useful delivery constants are preserved as the fallback.
`taxi_price_observations` source/repository support is ready; populating it requires an
owner-approved lawful acquisition/import process and data quality review.
