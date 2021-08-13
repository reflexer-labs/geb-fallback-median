# GEB Fallback Median

This repository consists in an oracle model that has two core price feeds as well as a fallback feed used to provide data for a GEB deployment.

## Mechanism Overview

Determining the new price used in the median is done in two steps.

The first step consists in reading prices from the two main oracles, `coreFeed` and `checkerFeed`.

In the second step, the median compares the two prices. If the `core` and `checker` prices are less than `threshold` percent away from each other, the `coreFeed` price is used. Otherwise, the median will use the price provided by the `fallbackFeed`.
