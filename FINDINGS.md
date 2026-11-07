# Findings: Hotel Bookings Analysis

All results come from the cleaned data in PostgreSQL (queries in `02_analysis.sql`). Each question is answered twice where the duplicate decision matters:

- **All rows**: `hotel_data_clean` (120,090 bookings)
- **Duplicates removed**: `hotel_bookings_unique` (91,658 bookings), which hides 28,432 rows that are identical to another row. Most of these look like cancelled block bookings (group and tour-operator rooms booked together).

## Key takeaways

1. **Duplicate handling changes the headline.** The cancellation rate is 37.1% with all rows and 28.9% without the likely block-booking duplicates.
2. **City Hotel cancels more than Resort Hotel** (41.7% vs 27.8%, or 31.8% vs 24.1% without duplicates), and the block bookings explain close to half of that gap.
3. **Non-refundable deposits are not a reason guests cancel.** 99.4% of Non Refund bookings were cancelled, but 97% come from the Groups and Offline TA/TO segments, mostly at the City Hotel.
4. **The earlier a guest books, the more likely they cancel**, from about 9% for 0 to 7 days ahead to over 50% for more than a year ahead.
5. **The Resort Hotel is seasonal in price, not in bookings.** Its nightly rate swings about fourfold between January and August.
6. **Online TA is the biggest segment and where most cancellations are.** It makes up 57% of unique bookings and about 70% of their cancellations.

---

## 1. Overview

| | All rows | Duplicates removed |
|---|---|---|
| Bookings | 120,090 | 91,658 |
| Cancellation rate | 37.1% | 28.9% |
| Average price per night (`adr`) | 101.82 | 105.65 |
| Average lead time | 104 days | 83 days |
| Average stay | 3.4 nights | 3.6 nights |

**What it means:** the flagged duplicates are early (about 21 more days of lead time), cheaper and almost all cancelled. Counting them moves the headline cancellation rate by more than 8 points.

## 2. Cancellations by hotel

| Hotel | All rows | Duplicates removed |
|---|---|---|
| City Hotel | 41.7% (79,776 bookings) | 31.8% (56,732) |
| Resort Hotel | 27.8% (40,314) | 24.1% (34,926) |

**What it means:** the City Hotel cancels more in both versions. The gap shrinks from 13.9 points to 7.7 points when duplicates are removed.

## 3. Cancellations by deposit type

| Deposit type | All rows | Duplicates removed |
|---|---|---|
| No Deposit | 28.4% (105,252) | 27.0% (89,087) |
| **Non Refund** | **99.4%** (14,675) | **97.4%** (2,450) |
| Refundable | 22.1% (163) | 24.0% (121) |

**Who makes Non Refund bookings (all rows):**

| Segment and hotel | Bookings | Cancelled |
|---|---|---|
| Groups, City Hotel | 7,699 | 99.9% |
| Offline TA/TO, City Hotel | 4,888 | 100.0% |
| Groups, Resort Hotel | 1,517 | 96.2% |
| All other combinations | 571 | mostly 73% to 99% |

**What it means:** 97% of Non Refund bookings come from Groups and Offline TA/TO, and 86% come from those two segments at the City Hotel. Non Refund marks one kind of booking (large group and tour-operator blocks) and is not a reason guests cancel.

**Caution:** the data shows the pattern, not the cause. The blocks may have been released together, or the deposit type may have been recorded after the cancellation. The column should not be used to predict cancellations without checking with the data owner.

## 4. Cancellations by lead time

| Lead time | All rows | Duplicates removed |
|---|---|---|
| 0 to 7 days | 9.6% | 8.6% |
| 8 to 30 days | 27.8% | 25.7% |
| 31 to 90 days | 37.7% | 32.6% |
| 91 to 180 days | 44.7% | 36.3% |
| 181 to 365 days | 55.6% | 42.2% |
| Over 365 days | 67.6% | 50.9% |
| Unknown (missing lead time) | 37.6% | 36.0% |

**What it means:** cancellation rises at every step. The pattern holds in both versions but is steeper with all rows, because the block bookings were made early and cancelled.

**Caution:** the 50.9% for bookings over 365 days is probably an upper estimate. The duplicate count is a lower bound, so a few cancelled block copies are still counted as unique and fall mostly in the long-lead-time bands.

## 5. Seasonality (2016, the only complete year, duplicates removed)

| | City Hotel | Resort Hotel |
|---|---|---|
| Average price, lowest | 75.86 (January) | 46.22 (January) |
| Average price, highest | 124.87 (September) | 191.83 (August) |
| Monthly bookings, range | 1,076 to 2,891 | 826 to 1,644 |
| Busiest months | August, October, September | October, August, March |
| Cancellation rate, range | 22.6% (January) to 38.9% (December) | 11.0% (January) to 33.3% (August) |

**What it means:**
- The Resort Hotel is seasonal in price. The nightly rate swings about fourfold between January and August, while its monthly bookings stay in a fairly narrow band. Its cancellation rate rises and falls with the season.
- The City Hotel is steadier. Its rate moves between about 76 and 125, and its bookings peak from August to October.

**Caution:** across all years, July and August have three years of data and the other months have two, so booking counts by month are not directly comparable. The 2016-only view fixes that.

## 6. Guest countries (duplicates removed)

| Country | Bookings | Share | Cancelled |
|---|---|---|---|
| Portugal (PRT) | 29,165 | 32.7% | 39.0% |
| United Kingdom (GBR) | 10,528 | 11.8% | 19.1% |
| France (FRA) | 8,903 | 10.0% | 19.4% |
| Spain (ESP) | 7,279 | 8.2% | 25.8% |
| Germany (DEU) | 5,527 | 6.2% | 19.2% |
| Italy (ITA) | 3,110 | 3.5% | 35.3% |
| Ireland (IRL) | 3,009 | 3.4% | 22.0% |
| Belgium (BEL) | 2,087 | 2.3% | 19.9% |
| Brazil (BRA) | 1,996 | 2.2% | 36.9% |
| China (CHN) | 1,927 | 2.2% | 32.2% |

The top ten countries make up about 82% of bookings with a known country. Shares are calculated over bookings with a known country only.

**What it means:** one in three bookings comes from Portugal, where both hotels are. Portuguese guests cancel about twice as often as guests from the UK, France, Germany, Ireland or Belgium. Italy, Brazil and China also cancel more (32% to 37%).

**Caution:** a country's cancellation rate can be a segment effect. The block bookings found earlier are mostly Portuguese, and some copies remain in the unique version. The data supports "cancellations are concentrated in Portuguese bookings", not "Portuguese guests are more likely to cancel".

## 7. Market segments

| Segment | Rows lost to duplicate removal | Cancelled (all rows) | Cancelled (unique) | Avg price (unique) | Avg lead time (unique) |
|---|---|---|---|---|---|
| Online TA | 7% (56,812 to 52,561) | 36.7% | 35.6% | 118.00 | 80 days |
| Offline TA/TO | 38% (24,372 to 15,159) | 34.4% | 18.2% | 82.21 | 110 days |
| Groups | **67%** (19,921 to 6,651) | 61.1% | 37.8% | 76.04 | 159 days |
| Direct | 6% (12,673 to 11,955) | 15.3% | 14.9% | 116.49 | 49 days |
| Corporate | 18% (5,323 to 4,389) | 18.8% | 13.0% | 68.45 | 17 days |
| Complementary | 5% (748 to 713) | 13.0% | 12.5% | 3.07 | 14 days |
| Aviation | 5% (239 to 228) | 21.8% | 20.2% | 100.18 | 4 days |

(`Undefined` has only 2 rows, both cancelled, and is ignored.)

**What it means:**
- Almost all duplicates sit in the two segments that sell blocks of rooms. Groups lost two thirds of its rows. This supports the block-booking explanation.
- Online TA is the largest segment (57% of unique bookings) and accounts for about 70% of their cancellations.
- Direct and Corporate guests rarely cancel (13% to 15%).
- Groups book far ahead (159 days) at lower prices, which is typical of contracts.
- Complementary bookings are free stays (average price about 3).

**Caution:** the unique figures for Groups and Offline TA/TO are probably upper estimates, because the duplicate count is a lower bound.

## 8. Revenue from completed stays (duplicates removed)

Estimated as price per night times nights, for `Check-Out` bookings only, in the currency units of `adr` (the currency is not stated in the data).

| Hotel | Year | Stays | Estimated revenue |
|---|---|---|---|
| City Hotel | 2015 (Jul to Dec) | 5,273 | 1,369,255 |
| City Hotel | 2016 | 18,972 | 5,858,515 |
| City Hotel | 2017 (Jan to Aug) | 13,225 | 4,846,799 |
| Resort Hotel | 2015 (Jul to Dec) | 5,450 | 2,373,561 |
| Resort Hotel | 2016 | 12,067 | 4,378,862 |
| Resort Hotel | 2017 (Jan to Aug) | 8,225 | 3,870,729 |

| Hotel | Total stays | Total estimated revenue |
|---|---|---|
| City Hotel | 37,470 | 12,074,569 |
| Resort Hotel | 25,742 | 10,623,152 |

**What it means:**
- In 2016, the only full year, the City Hotel earned about 5.9 million against 4.4 million for the Resort Hotel, roughly a third more, from about 57% more stays.
- Each Resort Hotel stay is worth more, about 363 against 309 for the City Hotel (about 18% more).
- Over the whole period the two hotels are closer, at 12.1 million and 10.6 million.

**Caution:** only 2016 is a full year, so years cannot be compared directly. Stays with a missing price or year were left out. Most flagged duplicates are cancelled bookings, so this query is likely little affected by the duplicate decision, but that was not checked separately.

---

## Limitations that apply to every result

- The duplicate count is a lower bound, so "duplicates removed" figures can still contain some block-booking copies.
- Some day/month swaps in `reservation_status_date` may remain, especially for cancelled bookings (estimated under 2% of rows). Results that do not use that column are unaffected.
- Missing values were kept as `NULL`, so each average is calculated over the rows that have a value.
- The data shows patterns, not causes. Where a cause is suggested, it is an interpretation.
