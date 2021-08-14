# GEB Fallback Median

This repository consists of an oracle model that has two core price feeds as well as a fallback feed used to provide collateral price data for a GEB deployment.

## Mechanism Overview

Determining the new price used in the median is done in two steps.

The first step consists in reading prices from the two main oracles, `coreFeed` and `checkerFeed`.

In the second step, the median compares the two prices. If the `core` and `checker` prices are less than `threshold` percent away from each other, the `coreFeed` price is used. Otherwise, the median will use the price provided by the `fallbackFeed`.

## What Could Go Wrong?

The following scenarios might make the median fall back on the `fallbackFeed` or completely fail.

- The `coreFeed` is manipulated and returns a price that far away from the one in `checkerFeed`. This will maje the median fall back on the `fallbackFeed`
- The `checkerFeed` is manipulated and returns a price that far away from the one in `coreFeed`. This will maje the median fall back on the `fallbackFeed`
- Both the `checker`/`core` feed and the `fallbackFeed` are manipulated and the median will return a faulty price
- Both the `checker`/`core` feed and the `fallbackFeed` return `0` so the median returns `(0, false)` when someone calls `getResultWithValidity()` and reverts when someone calls `read()`
- Either the `core` or the `checker` feed is updated faster than the other one which makes the two prices get further than `threshold` percent away from each other, in which case the `fallbackFeed` is used
- Either the `core` or the `checker` feed gets stale which makes the two prices get further than `threshold` percent away from each other, in which case the `fallbackFeed` is used
- Either the `core` or the `checker` feed as well as the `fallbackFeed` get stale, in which case the median returns `(0, false)` when someone calls `getResultWithValidity()` and reverts when someone calls `read()`
