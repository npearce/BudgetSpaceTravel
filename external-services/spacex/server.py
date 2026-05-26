import json
from pathlib import Path
from fastmcp import FastMCP

# Load data from JSON file
data_path = Path(__file__).parent / "data.json"
with open(data_path) as f:
    data = json.load(f)

# Create FastMCP server instance
mcp = FastMCP("SpaceX MCP Server")


@mcp.tool()
def get_vehicle_availability(vehicle_type: str | None = None) -> dict:
    """
    Get SpaceX vehicle availability and current status.
    Returns Falcon 9, Falcon Heavy, and Starship operational status, capacity specs, and next available dates.
    """
    vehicles = data["vehicles"]
    if vehicle_type:
        vehicles = [v for v in vehicles if vehicle_type.lower() in v["name"].lower()]
    return {
        "vehicles": vehicles,
        "count": len(vehicles),
        "last_updated": "2025-05-26T12:00:00Z",
    }


@mcp.tool()
def get_pricing_tiers(vehicle: str | None = None, orbit: str | None = None) -> dict:
    """
    Get SpaceX commercial pricing tiers by vehicle and orbit type.
    Returns pricing for LEO, GTO, GEO missions with payload class and lead times.
    """
    tiers = data["pricing_tiers"]
    if vehicle:
        tiers = [t for t in tiers if vehicle.lower() in t["vehicle"].lower()]
    if orbit:
        tiers = [t for t in tiers if orbit.upper() == t["orbit"]]
    return {
        "pricing_tiers": tiers,
        "count": len(tiers),
        "currency": "USD",
        "last_updated": "2025-05-26T12:00:00Z",
    }


@mcp.tool()
def get_flight_manifest(limit: int = 10) -> dict:
    """
    Get SpaceX flight manifest with scheduled launches.
    Returns mission names, launch dates, vehicles, payloads, and customer information.
    """
    manifest = data["flight_manifest"][:limit]
    return {
        "flights": manifest,
        "count": len(manifest),
        "total_flights": len(data["flight_manifest"]),
    }


@mcp.tool()
def get_booking_slots(vehicle: str | None = None) -> dict:
    """
    Get available SpaceX booking slots for upcoming launches.
    Returns launch windows, payload capacity, orbital capability, and pricing.
    """
    slots = data["booking_slots"]
    if vehicle:
        slots = [s for s in slots if vehicle.lower() in s["vehicle"].lower()]
    return {
        "booking_slots": slots,
        "count": len(slots),
        "currency": "USD",
        "last_updated": "2025-05-26T12:00:00Z",
    }


@mcp.tool()
def get_internal_cost_model() -> dict:
    """
    Get SpaceX internal cost model and manufacturing expenses.
    Returns per-vehicle manufacturing costs, launch operations, margins, and market strategy.
    """
    return data["internal_cost_model"]


if __name__ == "__main__":
    mcp.run(transport="http", host="0.0.0.0", port=8000)
