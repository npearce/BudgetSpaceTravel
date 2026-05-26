import json
from pathlib import Path
from fastmcp import FastMCP

# Load data from JSON file
data_path = Path(__file__).parent / "data.json"
with open(data_path) as f:
    data = json.load(f)

# Create FastMCP server instance
mcp = FastMCP("NASA MCP Server")


@mcp.tool()
def get_launch_windows(mission_filter: str | None = None) -> dict:
    """
    Get NASA launch windows from Kennedy Space Center and other launch facilities.
    Returns scheduled launch opportunities with mission details, crew/cargo capacity.
    """
    windows = data["launch_windows"]
    if mission_filter:
        windows = [w for w in windows if mission_filter.lower() in w["mission"].lower()]
    return {
        "launch_windows": windows,
        "count": len(windows),
        "facility": "Kennedy Space Center Operations",
    }


@mcp.tool()
def get_weather_conditions(location: str | None = None) -> dict:
    """
    Get current and 7-day weather forecasts for NASA launch sites.
    Returns temperature, wind, precipitation, sea state, and go/no-go recommendations.
    """
    if not location:
        location = "kennedy_space_center"

    location_key = location.lower().replace(" ", "_")
    if location_key in data["weather_conditions"]:
        return data["weather_conditions"][location_key]
    return {
        "error": f"Weather data not available for {location}",
        "available_locations": list(data["weather_conditions"].keys()),
    }


@mcp.tool()
def get_launch_site_status(site_id: str | None = None) -> dict:
    """
    Get operational status of NASA launch facilities.
    Returns facility status, inspection history, maintenance windows, and pad availability.
    """
    sites = data["launch_sites"]
    if site_id:
        sites = [s for s in sites if s["id"].upper() == site_id.upper()]
    return {
        "launch_sites": sites,
        "count": len(sites),
        "last_updated": "2025-05-26T12:00:00Z",
    }


@mcp.tool()
def get_range_safety_status() -> dict:
    """
    Get range safety clearance status from Kennedy Space Center Range Operations.
    Returns weather go/no-go, vehicle readiness, tracking system status, and restricted airspace.
    """
    return data["range_safety"]


@mcp.tool()
def get_cafeteria_menu(date: str | None = None) -> dict:
    """
    Get the Kennedy Space Center Operations Facility cafeteria menu.
    Returns breakfast, lunch, and dinner options with pricing and nutritional info.
    """
    menu = data["cafeteria_menu"].copy()
    if date:
        menu["date"] = date
    return menu


if __name__ == "__main__":
    mcp.run(transport="http", host="0.0.0.0", port=8000)
