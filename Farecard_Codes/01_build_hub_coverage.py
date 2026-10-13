"""Build hub-level sheltered-walkway coverage for Figures 6 and 7.

The script reads the April 2022 LTA layer, 2022-01-01 OSM covered ways, and the
common footway network. Source files are never edited; invalid geometry is
repaired in memory before spatial operations.
"""

from __future__ import annotations

import csv
import json
import os
from datetime import datetime, timezone
from pathlib import Path
import sys


if len(sys.argv) != 2:
    raise SystemExit("Usage: python 01_build_hub_coverage.py PROJECT_ROOT")

PROJECT_ROOT = Path(sys.argv[1]).resolve()
DATA = PROJECT_ROOT / "Data"
RESTRICTED = DATA / "Restricted Inputs"
PUBLIC = DATA / "Public Inputs"
WORK = DATA / "Working Data"
LOGS = PROJECT_ROOT / "Logs"

# Derive the QGIS install paths from the QGIS Python executable itself.
qgis_macos = Path(sys.executable).resolve().parents[1]
os.environ.setdefault("QGIS_PREFIX_PATH", str(qgis_macos))
os.environ.setdefault("PROJ_LIB", str(qgis_macos.parent / "Resources" / "proj"))
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from qgis.core import (  # noqa: E402
    QgsApplication,
    QgsCoordinateReferenceSystem,
    QgsCoordinateTransform,
    QgsFeature,
    QgsGeometry,
    QgsPointXY,
    QgsProject,
    QgsSpatialIndex,
)


HUB_CSV = WORK / "transithub_v4_for_qgis.csv"
LTA_SHP = RESTRICTED / "LTA Apr2022" / "CoveredLinkWay.shp"
OSM_COVERED_2022 = PUBLIC / "OSM" / "covered_20220101.shp"
FOOTWAY_FALLBACK = PUBLIC / "OSM" / "footway_fallback.shp"
OUTPUT_CSV = WORK / "hub_coverage_apr22_osm22_5m.csv"
OUTPUT_AUDIT = WORK / "hub_coverage_apr22_osm22_5m_audit.json"
OUTPUT_LOG = LOGS / "hub_coverage_apr22_osm22_5m.log"
TARGET_CRS = QgsCoordinateReferenceSystem("EPSG:3414")
TOLERANCE_M = 5


def log(message: str) -> None:
    stamp = datetime.now(timezone.utc).isoformat(timespec="seconds")
    line = f"[{stamp}] {message}"
    print(line, flush=True)
    with OUTPUT_LOG.open("a", encoding="utf-8") as handle:
        handle.write(line + "\n")


def normalize_hub(code: str) -> str:
    code = code.strip().upper()
    if code in {"CE2-NS27-TE20", "NS27-CE2-TE20", "NS27-CE2"}:
        return "CE2-NS27"
    return code


def load_layer(path: Path, name: str):
    if not path.exists():
        raise FileNotFoundError(path)
    from qgis.core import QgsVectorLayer

    layer = QgsVectorLayer(str(path), name, "ogr")
    if not layer.isValid():
        raise RuntimeError(f"Invalid spatial layer: {path}")
    return layer


def transform_geometries(layer):
    transform = QgsCoordinateTransform(layer.crs(), TARGET_CRS, QgsProject.instance())
    records = []
    invalid_fixed = 0
    empty_dropped = 0
    for feature in layer.getFeatures():
        geometry = QgsGeometry(feature.geometry())
        if geometry.isEmpty():
            empty_dropped += 1
            continue
        geometry.transform(transform)
        if not geometry.isGeosValid():
            invalid_fixed += 1
            geometry = geometry.makeValid()
        if geometry.isEmpty():
            empty_dropped += 1
            continue
        records.append((feature, geometry))
    return records, invalid_fixed, empty_dropped


def unary_union(geometries):
    valid = [geometry for geometry in geometries if geometry and not geometry.isEmpty()]
    return QgsGeometry.unaryUnion(valid) if valid else QgsGeometry()


def indexed_line_source(layer):
    records, invalid_fixed, empty_dropped = transform_geometries(layer)
    geometries = {}
    spatial_index = QgsSpatialIndex()
    for fid, (_, geometry) in enumerate(records):
        feature = QgsFeature()
        feature.setId(fid)
        feature.setGeometry(geometry)
        spatial_index.addFeature(feature)
        geometries[fid] = geometry
    unioned = unary_union(geometries.values())
    return {
        "index": spatial_index,
        "geometries": geometries,
        "union": unioned,
        "feature_count": len(records),
        "invalid_fixed": invalid_fixed,
        "empty_dropped": empty_dropped,
    }


def clipped_network(network, mask):
    pieces = []
    for fid in network["index"].intersects(mask.boundingBox()):
        geometry = network["geometries"][fid]
        if geometry.intersects(mask):
            clipped = geometry.intersection(mask)
            if not clipped.isEmpty():
                pieces.append(clipped)
    return unary_union(pieces)


def read_hubs():
    transform = QgsCoordinateTransform(
        QgsCoordinateReferenceSystem("EPSG:4326"), TARGET_CRS, QgsProject.instance()
    )
    hubs = []
    seen = set()
    with HUB_CSV.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            code = normalize_hub(row["pt_code_hub"])
            if code in seen:
                raise RuntimeError(f"Duplicate normalized hub code: {code}")
            seen.add(code)
            point = transform.transform(
                QgsPointXY(float(row["hub_long"]), float(row["hub_lat"]))
            )
            hubs.append(
                {
                    "hub_code": code,
                    "hub_name": row["hub_name"],
                    "hub_type": row["hub_type"],
                    "policy_radius_m": int(row["policy_radius_m"]),
                    "geometry": QgsGeometry.fromPointXY(point),
                }
            )
    for hub in hubs:
        expected_radius = 400 if hub["hub_type"] in {"MRT", "MRT/LRT"} else 200
        if hub["policy_radius_m"] != expected_radius:
            raise RuntimeError(
                f"Policy-radius mismatch for {hub['hub_code']}: "
                f"{hub['policy_radius_m']} != {expected_radius}"
            )
    return hubs


def main() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    LOGS.mkdir(parents=True, exist_ok=True)
    OUTPUT_LOG.write_text("", encoding="utf-8")

    app = QgsApplication([], False)
    app.initQgis()
    try:
        log("QGIS initialized; output CRS=EPSG:3414; matching tolerance=5m")
        hubs = read_hubs()
        if len(hubs) != 168:
            raise AssertionError(f"Expected 168 hubs, found {len(hubs)}")

        lta_layer = load_layer(LTA_SHP, "lta_apr2022")
        osm_layer = load_layer(OSM_COVERED_2022, "osm_covered_20220101")
        footway_layer = load_layer(FOOTWAY_FALLBACK, "footway_fallback")
        source_crs = {
            "lta_apr2022": lta_layer.crs().authid(),
            "osm_20220101": osm_layer.crs().authid(),
            "footway_fallback": footway_layer.crs().authid(),
        }

        lta_records, lta_invalid, lta_empty = transform_geometries(lta_layer)
        lta_mask = unary_union(geometry for _, geometry in lta_records)
        osm_network = indexed_line_source(osm_layer)
        footway = indexed_line_source(footway_layer)
        lta_tolerance_mask = lta_mask.buffer(TOLERANCE_M, 12)
        osm_tolerance_mask = osm_network["union"].buffer(TOLERANCE_M, 12)
        sheltered_union = unary_union([lta_tolerance_mask, osm_tolerance_mask])

        rows = []
        maximum_union_identity_gap_m = 0.0
        for index, hub in enumerate(hubs, start=1):
            policy_radius_m = hub["policy_radius_m"]
            policy_buffer = hub["geometry"].buffer(policy_radius_m, 24)
            denominator_network = clipped_network(footway, policy_buffer)
            denominator_m = denominator_network.length()
            # Localize the national mask before the line intersection. This
            # reproduces the audited QGIS overlay order and avoids GEOS overlay
            # sensitivity from intersecting each small clip with a nationwide
            # mixed polygon/line collection.
            local_lta = lta_tolerance_mask.intersection(policy_buffer)
            local_osm = osm_tolerance_mask.intersection(policy_buffer)
            local_sheltered_union = sheltered_union.intersection(policy_buffer)
            lta_numerator_m = denominator_network.intersection(local_lta).length()
            osm_numerator_m = denominator_network.intersection(local_osm).length()
            numerator_m = denominator_network.intersection(local_sheltered_union).length()
            overlap_m = lta_numerator_m + osm_numerator_m - numerator_m
            identity_gap_m = abs(
                lta_numerator_m + osm_numerator_m - overlap_m - numerator_m
            )
            maximum_union_identity_gap_m = max(
                maximum_union_identity_gap_m, identity_gap_m
            )
            if denominator_m <= 0:
                raise AssertionError(f"Nonpositive denominator for {hub['hub_code']}")
            for value_name, value in {
                "lta_numerator_m": lta_numerator_m,
                "osm_numerator_m": osm_numerator_m,
                "union_numerator_m": numerator_m,
            }.items():
                if value < -1e-6 or value > denominator_m + 1e-5:
                    raise AssertionError(
                        f"Coverage bounds fail for {hub['hub_code']} "
                        f"{value_name}: {value}/{denominator_m}"
                    )
            if overlap_m < -1e-5:
                raise AssertionError(
                    f"Negative LTA-OSM overlap for {hub['hub_code']}: {overlap_m}"
                )
            rows.append(
                {
                    "hub_code": hub["hub_code"],
                    "hub_name": hub["hub_name"],
                    "hub_type": hub["hub_type"],
                    "radius_m": policy_radius_m,
                    "tolerance_m": TOLERANCE_M,
                    "footway_denominator_m": denominator_m,
                    "lta_apr2022_numerator_m": lta_numerator_m,
                    "osm_20220101_numerator_m": osm_numerator_m,
                    "lta_osm_overlap_m": max(0.0, overlap_m),
                    "sheltered_union_numerator_m": numerator_m,
                    "coverage_apr22_osm22_5m": numerator_m / denominator_m,
                    "coverage_definition": "Apr2022_LTA_plus_OSM_20220101_5m_on_common_footway",
                    "denominator_definition": "locally_available_OSM_footway_fallback",
                }
            )
            if index % 25 == 0 or index == len(hubs):
                log(f"Processed hubs: {index}/{len(hubs)}")

        with OUTPUT_CSV.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)

        audit = {
            "generated_utc": datetime.now(timezone.utc).isoformat(),
            "source_paths": {
                "hubs": str(HUB_CSV.relative_to(PROJECT_ROOT)),
                "lta_apr2022": str(LTA_SHP.relative_to(PROJECT_ROOT)),
                "osm_20220101": str(OSM_COVERED_2022.relative_to(PROJECT_ROOT)),
                "footway_fallback": str(FOOTWAY_FALLBACK.relative_to(PROJECT_ROOT)),
            },
            "source_crs": source_crs,
            "target_crs": "EPSG:3414",
            "hub_count": len(hubs),
            "lta_apr2022_features": len(lta_records),
            "lta_invalid_fixed_in_memory": lta_invalid,
            "lta_empty_dropped": lta_empty,
            "osm_20220101_features": osm_network["feature_count"],
            "osm_invalid_fixed_in_memory": osm_network["invalid_fixed"],
            "osm_empty_dropped": osm_network["empty_dropped"],
            "footway_line_features": footway["feature_count"],
            "footway_invalid_fixed_in_memory": footway["invalid_fixed"],
            "footway_empty_dropped": footway["empty_dropped"],
            "policy_radius_counts": {
                "200": sum(hub["policy_radius_m"] == 200 for hub in hubs),
                "400": sum(hub["policy_radius_m"] == 400 for hub in hubs),
            },
            "tolerance_m": TOLERANCE_M,
            "maximum_union_identity_gap_m": maximum_union_identity_gap_m,
            "exposure_role": "backfilled descriptive proxy",
            "analysis_sample": "MRT, MRT/LRT, and LRT; BUS-only excluded downstream",
        }
        OUTPUT_AUDIT.write_text(json.dumps(audit, indent=2), encoding="utf-8")
        log(f"Coverage output written: {OUTPUT_CSV}")
        log(
            "Coverage mean across 168 hubs="
            f"{sum(row['coverage_apr22_osm22_5m'] for row in rows)/len(rows):.8f}"
        )
    finally:
        # QGIS-LTR can segfault during exitQgis() in a headless macOS process
        # after all outputs have been closed. Process exit releases the runtime.
        log("QGIS processing block finished")


if __name__ == "__main__":
    main()
