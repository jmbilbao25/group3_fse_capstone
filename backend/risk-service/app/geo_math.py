"""
Deterministic Geographic Mathematics and Velocity Analysis.
Implements the Haversine spherical distance formula and physical speed checks.
"""

import math
from datetime import datetime, timezone
from typing import Optional, Tuple, Dict, Any


EARTH_RADIUS_KM = 6371.0
IMPOSSIBLE_TRAVEL_SPEED_KMH = 800.0  # Commercial flight maximum ground speed
HIGH_VELOCITY_TRANSIT_KMH = 150.0    # High-speed rail / rapid vehicle transit
VPN_DISCREPANCY_THRESHOLD_KM = 250.0 # Delta indicating VPN or GPS spoofing


def calculate_haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculates great-circle distance between two GPS coordinates in kilometers
    using the spherical Haversine formula.
    """
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    
    a = (math.sin(dlat / 2.0) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2.0) ** 2)
    
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return EARTH_RADIUS_KM * c


def evaluate_travel_velocity(
    current_lat: float,
    current_lon: float,
    current_timestamp: datetime,
    prev_lat: float,
    prev_lon: float,
    prev_timestamp: datetime
) -> Tuple[float, float, float]:
    """
    Computes distance (km), elapsed time (hours), and physical speed (km/h)
    between two consecutive transactions.
    """
    distance_km = calculate_haversine_distance(prev_lat, prev_lon, current_lat, current_lon)
    
    # Calculate elapsed time in hours (minimum 1 second to avoid division by zero)
    elapsed_seconds = max((current_timestamp - prev_timestamp).total_seconds(), 1.0)
    elapsed_hours = elapsed_seconds / 3600.0
    
    velocity_kmh = distance_km / elapsed_hours
    return distance_km, elapsed_hours, velocity_kmh


def analyze_location_signals(
    current_lat: float,
    current_lon: float,
    home_lat: float,
    home_lon: float,
    prev_lat: Optional[float] = None,
    prev_lon: Optional[float] = None,
    prev_timestamp_iso: Optional[str] = None,
    ip_lat: Optional[float] = None,
    ip_lon: Optional[float] = None
) -> Dict[str, Any]:
    """
    Full deterministic evaluation of location and movement signals.
    """
    now = datetime.now(timezone.utc)
    
    # 1. Distance from primary registered home anchor
    distance_from_home_km = calculate_haversine_distance(
        home_lat, home_lon, current_lat, current_lon
    )
    
    # 2. Velocity and impossible travel check
    distance_from_last_km = 0.0
    elapsed_minutes = 0.0
    velocity_kmh = 0.0
    is_impossible_travel = False
    is_high_speed_transit = False
    
    if prev_lat is not None and prev_lon is not None and prev_timestamp_iso:
        try:
            prev_time = datetime.fromisoformat(prev_timestamp_iso.replace("Z", "+00:00"))
            dist_km, el_hours, speed_kmh = evaluate_travel_velocity(
                current_lat, current_lon, now,
                prev_lat, prev_lon, prev_time
            )
            distance_from_last_km = dist_km
            elapsed_minutes = el_hours * 60.0
            velocity_kmh = speed_kmh
            
            if velocity_kmh > IMPOSSIBLE_TRAVEL_SPEED_KMH:
                is_impossible_travel = True
            elif velocity_kmh > HIGH_VELOCITY_TRANSIT_KMH:
                is_high_speed_transit = True
        except Exception:
            pass
            
    # 3. GPS vs IP Geolocation Discrepancy
    ip_discrepancy_km = 0.0
    is_vpn_detected = False
    if ip_lat is not None and ip_lon is not None:
        ip_discrepancy_km = calculate_haversine_distance(
            current_lat, current_lon, ip_lat, ip_lon
        )
        if ip_discrepancy_km > VPN_DISCREPANCY_THRESHOLD_KM:
            is_vpn_detected = True

    return {
        "distance_from_home_km": round(distance_from_home_km, 2),
        "distance_from_last_km": round(distance_from_last_km, 2),
        "elapsed_minutes": round(elapsed_minutes, 1),
        "velocity_kmh": round(velocity_kmh, 1),
        "is_impossible_travel": is_impossible_travel,
        "is_high_speed_transit": is_high_speed_transit,
        "ip_discrepancy_km": round(ip_discrepancy_km, 2),
        "is_vpn_detected": is_vpn_detected,
    }
