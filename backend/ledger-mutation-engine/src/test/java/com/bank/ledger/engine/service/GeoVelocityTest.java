package com.bank.ledger.engine.service;

import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;

class GeoVelocityTest {

    private static final double MANILA_LAT = 14.5995, MANILA_LON = 120.9842;
    private static final double LONDON_LAT = 51.5074, LONDON_LON = -0.1278;
    private static final double CEBU_LAT = 10.3157, CEBU_LON = 123.8854;

    @Test
    void manilaToLondonInFiveMinutesIsImpossible() {
        Instant now = Instant.now();
        GeoVelocity.Result r = GeoVelocity.assess(MANILA_LAT, MANILA_LON, now.minusSeconds(300), LONDON_LAT, LONDON_LON, now);
        assertThat(r.distanceKm()).isBetween(10_700.0, 10_800.0);
        assertThat(r.impossible()).isTrue();
    }

    @Test
    void manilaToCebuAfterAFlightIsPossible() {
        Instant now = Instant.now();
        GeoVelocity.Result r = GeoVelocity.assess(MANILA_LAT, MANILA_LON, now.minusSeconds(3 * 3600), CEBU_LAT, CEBU_LON, now);
        assertThat(r.distanceKm()).isBetween(550.0, 600.0);
        assertThat(r.impossible()).isFalse();
    }

    @Test
    void sameCityTwiceInOneMinuteIsNotFlagged() {
        Instant now = Instant.now();
        GeoVelocity.Result r = GeoVelocity.assess(MANILA_LAT, MANILA_LON, now.minusSeconds(10), 14.55, 121.02, now);
        assertThat(r.impossible()).isFalse();
    }

    @Test
    void noPreviousTransferMeansNoSignal() {
        assertThat(GeoVelocity.assess(null, null, null, LONDON_LAT, LONDON_LON, Instant.now())).isEqualTo(GeoVelocity.Result.NONE);
    }
}
