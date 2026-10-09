package com.bank.ledger.engine.service;

import java.time.Duration;
import java.time.Instant;

/**
 * Impossible-travel check between a customer's previous transfer and this one.
 *
 * Mirrors risk-service geo_math.py (haversine, 800 km/h ceiling) so the ledger
 * can hold a transfer even when the risk service is unreachable.
 */
public final class GeoVelocity {

    static final double EARTH_RADIUS_KM = 6371.0;
    /** Commercial flight ground speed. */
    static final double IMPOSSIBLE_SPEED_KMH = 800.0;
    /** GPS and IP drift inside one metro area should never trip the rule. */
    static final double MIN_DISTANCE_KM = 100.0;

    private GeoVelocity() {
    }

    public record Result(double distanceKm, double minutes, double speedKmh, boolean impossible) {
        public static final Result NONE = new Result(0, 0, 0, false);
    }

    public static double haversineKm(double lat1, double lon1, double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.pow(Math.sin(dLat / 2), 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) * Math.pow(Math.sin(dLon / 2), 2);
        return EARTH_RADIUS_KM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    /** Returns {@link Result#NONE} when there is no previous located transfer. */
    public static Result assess(Double prevLat, Double prevLon, Instant prevAt,
                                double lat, double lon, Instant now) {
        if (prevLat == null || prevLon == null || prevAt == null) {
            return Result.NONE;
        }
        double km = haversineKm(prevLat, prevLon, lat, lon);
        // Floor at one minute so back-to-back demo transfers still yield a finite speed.
        double minutes = Math.max(Duration.between(prevAt, now).toSeconds() / 60.0, 1.0);
        double kmh = km / (minutes / 60.0);
        return new Result(km, minutes, kmh, km >= MIN_DISTANCE_KM && kmh > IMPOSSIBLE_SPEED_KMH);
    }
}
