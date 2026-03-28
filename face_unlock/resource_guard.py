"""
Pre-auth system resource checks. Uses ONLY stdlib — no heavy imports.
This module must add <5ms latency and import nothing beyond stdlib.
"""

import os
import time


def get_available_ram_mb():
    """Read MemAvailable from /proc/meminfo. Returns MB or None on failure."""
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                if line.startswith("MemAvailable:"):
                    # Format: "MemAvailable:    1234567 kB"
                    parts = line.split()
                    return int(parts[1]) / 1024  # kB -> MB
    except (OSError, IOError, ValueError, IndexError):
        return None
    return None


def get_cpu_idle_percent():
    """Read CPU idle % from /proc/stat. Takes two samples 50ms apart.
    Returns idle percentage or None on failure."""
    try:
        def read_cpu_times():
            with open("/proc/stat", "r") as f:
                line = f.readline()  # First line: cpu  user nice system idle ...
            parts = line.split()
            # cpu user nice system idle iowait irq softirq steal
            values = [int(x) for x in parts[1:]]
            total = sum(values)
            idle = values[3]  # idle is 4th field (index 3)
            return total, idle

        total1, idle1 = read_cpu_times()
        time.sleep(0.05)  # 50ms
        total2, idle2 = read_cpu_times()

        total_diff = total2 - total1
        idle_diff = idle2 - idle1

        if total_diff == 0:
            return 100.0  # No CPU activity = 100% idle

        return (idle_diff / total_diff) * 100.0

    except (OSError, IOError, ValueError, IndexError):
        return None


def check_resources(config=None):
    """Check system resources before face auth.

    Args:
        config: dict with keys min_available_ram_mb, min_cpu_idle_percent,
                resource_check_enabled. Uses defaults if None.

    Returns:
        (ok, reason): ok=True if resources are sufficient, reason explains failure.
    """
    if config is None:
        config = {}

    if not config.get("resource_check_enabled", True):
        return True, "Resource check disabled"

    min_ram_mb = config.get("min_available_ram_mb", 300)
    min_cpu_idle = config.get("min_cpu_idle_percent", 10)

    # Check available RAM
    available_ram = get_available_ram_mb()
    if available_ram is None:
        # Can't read /proc/meminfo — fail open (proceed with auth)
        return True, "Warning: could not read /proc/meminfo, proceeding anyway"

    if available_ram < min_ram_mb:
        return False, (
            f"Face auth skipped: only {available_ram:.0f}MB RAM available, "
            f"need {min_ram_mb}MB minimum"
        )

    # Check CPU idle
    cpu_idle = get_cpu_idle_percent()
    if cpu_idle is None:
        # Can't read /proc/stat — fail open
        return True, "Warning: could not read /proc/stat, proceeding anyway"

    if cpu_idle < min_cpu_idle:
        return False, (
            f"Face auth skipped: CPU only {cpu_idle:.1f}% idle, "
            f"need {min_cpu_idle}% minimum"
        )

    return True, f"Resources OK: {available_ram:.0f}MB RAM, {cpu_idle:.1f}% CPU idle"
