"""Build the editable manuscript Figure 6 map package.

The script reads the pooled hub metrics and MP2019 subzones, then writes a
GeoPackage, portable QGZ, preview PNG, audit JSON, and log.
"""

from __future__ import annotations

import csv
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import statistics
import sys
import zipfile


if len(sys.argv) != 2:
    raise SystemExit("Usage: python 03_build_figure6_map.py PROJECT_ROOT")

PROJECT_ROOT = Path(sys.argv[1]).resolve()
DATA = PROJECT_ROOT / "Data"
WORK = DATA / "Working Data"
PUBLIC = DATA / "Public Inputs"
FIGURES = PROJECT_ROOT / "Figures"
LOGS = PROJECT_ROOT / "Logs"

SUBZONE_SHP = PUBLIC / "MP2019" / "subzone2019_shp.shp"
HUB_COORDS_CSV = WORK / "transithub_v4_for_qgis.csv"
HUB_METRICS_CSV = WORK / "figure6_hub_pooled_working.csv"

OUTPUT_GPKG = WORK / "figure6_subzone_source.gpkg"
OUTPUT_QGZ = FIGURES / "figure6_spatial_distribution.qgz"
OUTPUT_PNG = FIGURES / "figure6_spatial_distribution_preview.png"
OUTPUT_AUDIT = WORK / "figure6_subzone_source_audit.json"
OUTPUT_LOG = LOGS / "figure6_map_build.log"

TMP_GPKG = WORK / ".figure6_subzone_source.tmp.gpkg"
TMP_QGZ = FIGURES / ".figure6_spatial_distribution.tmp.qgz"
TMP_QGZ_REL = FIGURES / ".figure6_spatial_distribution.relative.tmp.qgz"
TMP_PNG = FIGURES / ".figure6_spatial_distribution_preview.tmp.png"
TMP_AUDIT = WORK / ".figure6_subzone_source_audit.tmp.json"

for directory in (WORK, FIGURES, LOGS):
    directory.mkdir(parents=True, exist_ok=True)

qgis_macos = Path(sys.executable).resolve().parents[1]
os.environ.setdefault("QGIS_PREFIX_PATH", str(qgis_macos))
os.environ.setdefault("PROJ_LIB", str(qgis_macos.parent / "Resources" / "proj"))
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from qgis.core import (
    Qgis,
    QgsApplication,
    QgsCoordinateReferenceSystem,
    QgsCoordinateTransform,
    QgsFeature,
    QgsField,
    QgsFillSymbol,
    QgsGeometry,
    QgsGraduatedSymbolRenderer,
    QgsLayoutExporter,
    QgsLayoutItemLabel,
    QgsLayoutItemLegend,
    QgsLayoutItemMap,
    QgsLayoutMeasurement,
    QgsLayoutPoint,
    QgsLayoutSize,
    QgsMarkerSymbol,
    QgsPrintLayout,
    QgsProject,
    QgsRectangle,
    QgsRendererRange,
    QgsSingleSymbolRenderer,
    QgsSpatialIndex,
    QgsUnitTypes,
    QgsVectorFileWriter,
    QgsVectorLayer,
)
from qgis.PyQt.QtCore import QVariant
from qgis.PyQt.QtGui import QColor, QFont


def log(message: str) -> None:
    stamp = datetime.now(timezone.utc).isoformat(timespec="seconds")
    line = f"[{stamp}] {message}"
    print(line, flush=True)
    with OUTPUT_LOG.open("a", encoding="utf-8") as handle:
        handle.write(line + "\n")


def require(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(path)


def read_csv_keyed(path: Path, key: str) -> dict[str, dict[str, str]]:
    rows: dict[str, dict[str, str]] = {}
    with path.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            value = row[key].strip().upper()
            if value in rows:
                raise RuntimeError(f"Duplicate {key}={value} in {path}")
            rows[value] = row
    return rows


def f(row: dict[str, str], name: str) -> float:
    return float(row[name])


def i(row: dict[str, str], name: str) -> int:
    return int(round(float(row[name])))


def pearson(a: list[float], b: list[float]) -> float:
    ma = statistics.mean(a)
    mb = statistics.mean(b)
    numerator = sum((x - ma) * (y - mb) for x, y in zip(a, b))
    denominator = math.sqrt(
        sum((x - ma) ** 2 for x in a) * sum((y - mb) ** 2 for y in b)
    )
    return numerator / denominator


def average_ranks(values: list[float]) -> list[float]:
    order = sorted(range(len(values)), key=values.__getitem__)
    ranks = [0.0] * len(values)
    position = 0
    while position < len(order):
        end = position + 1
        while end < len(order) and values[order[end]] == values[order[position]]:
            end += 1
        rank = (position + 1 + end) / 2
        for idx in order[position:end]:
            ranks[idx] = rank
        position = end
    return ranks


def spearman(a: list[float], b: list[float]) -> float:
    return pearson(average_ranks(a), average_ranks(b))


def quantile_breaks(values: list[float], classes: int = 5) -> list[float]:
    ordered = sorted(values)
    breaks = [ordered[0]]
    for k in range(1, classes):
        position = k * (len(ordered) - 1) / classes
        lower = math.floor(position)
        upper = math.ceil(position)
        fraction = position - lower
        value = ordered[lower] * (1 - fraction) + ordered[upper] * fraction
        breaks.append(value)
    breaks.append(ordered[-1])
    return breaks


def quantile_class(value: float, breaks: list[float]) -> int:
    for idx in range(1, len(breaks)):
        if value <= breaks[idx] or idx == len(breaks) - 1:
            return idx
    raise AssertionError(value)


def write_memory_layer(
    name: str,
    geometry_type: str,
    crs_authid: str,
    fields: list[QgsField],
    rows: list[list[object]],
    geometries: list[QgsGeometry],
) -> None:
    layer = QgsVectorLayer(f"{geometry_type}?crs={crs_authid}", name, "memory")
    provider = layer.dataProvider()
    provider.addAttributes(fields)
    layer.updateFields()
    features: list[QgsFeature] = []
    for row, geometry in zip(rows, geometries):
        feature = QgsFeature(layer.fields())
        feature.setAttributes(row)
        feature.setGeometry(geometry)
        features.append(feature)
    provider.addFeatures(features)
    layer.updateExtents()
    options = QgsVectorFileWriter.SaveVectorOptions()
    options.driverName = "GPKG"
    options.layerName = name
    options.actionOnExistingFile = (
        QgsVectorFileWriter.CreateOrOverwriteFile
        if not TMP_GPKG.exists()
        else QgsVectorFileWriter.CreateOrOverwriteLayer
    )
    result = QgsVectorFileWriter.writeAsVectorFormatV3(
        layer,
        str(TMP_GPKG),
        QgsProject.instance().transformContext(),
        options,
    )
    if result[0] != QgsVectorFileWriter.NoError:
        raise RuntimeError(f"Failed to write {name}: {result}")


def make_fill(color: str, outline: str = "#ffffff", width: float = 0.12):
    return QgsFillSymbol.createSimple(
        {
            "color": color,
            "outline_color": outline,
            "outline_width": str(width),
            "outline_width_unit": "MM",
        }
    )


def graduated_renderer(
    field: str,
    values: list[float],
    colors: list[str],
    decimals: int = 2,
) -> tuple[QgsGraduatedSymbolRenderer, list[float]]:
    breaks = quantile_breaks(values, len(colors))
    ranges: list[QgsRendererRange] = []
    epsilon = max(1e-9, (max(values) - min(values)) * 1e-9)
    for idx, color in enumerate(colors):
        lower = breaks[idx] - (epsilon if idx == 0 else 0)
        upper = breaks[idx + 1] + (epsilon if idx == len(colors) - 1 else 0)
        label = f"{breaks[idx]:.{decimals}f}–{breaks[idx + 1]:.{decimals}f}"
        ranges.append(QgsRendererRange(lower, upper, make_fill(color), label))
    return QgsGraduatedSymbolRenderer(field, ranges), breaks


def set_aliases(layer: QgsVectorLayer) -> None:
    aliases = {
        "sz_code":     "Subzone code",
        "sz_name":     "Subzone name",
        "pa_name":     "Planning area",
        "region":      "Region",
        "has_data":    "Has analysis hubs",
        "n_hubs":      "Number of analysis hubs",
        "n_mrt":       "MRT hubs",
        "n_mrtlrt":    "MRT/LRT hubs",
        "n_lrt":       "Pure LRT hubs",
        "n_r400":      "Hubs using 400 m radius",
        "n_r200":      "Hubs using 200 m radius",
        "hub_codes":   "Hub codes",
        "cov_he_pct":  "Coverage, equal-hub mean (%)",
        "short_he_pp": "Short-flow share, equal-hub mean (pp)",
        "cov_dw_pct":  "Coverage, denominator-weighted (%)",
        "short_tw_pp": "Short-flow share, trip-weighted (pp)",
        "shelter_m":   "Summed sheltered numerator (m)",
        "footway_m":   "Summed footway denominator (m)",
        "shortflow":   "Summed policy-area route<=800 m flows",
        "allflow":     "Summed all hub-associated flows",
        "cov_gap_pp":  "Equal-hub minus denominator-weighted coverage (pp)",
        "short_gap":   "Equal-hub minus trip-weighted share (pp)",
    }
    for name, alias in aliases.items():
        idx = layer.fields().indexOf(name)
        if idx >= 0:
            layer.setFieldAlias(idx, alias)


def relativize_qgz(qgz_path: Path, absolute_gpkg: Path) -> None:
    relative_gpkg = "../Data/Working Data/figure6_subzone_source.gpkg"
    with zipfile.ZipFile(qgz_path, "r") as source, zipfile.ZipFile(
        TMP_QGZ_REL, "w", compression=zipfile.ZIP_DEFLATED
    ) as target:
        for info in source.infolist():
            payload = source.read(info.filename)
            if info.filename.endswith(".qgs"):
                payload = payload.replace(
                    str(absolute_gpkg).encode("utf-8"),
                    relative_gpkg.encode("utf-8"),
                )
            target.writestr(info, payload)
    os.replace(TMP_QGZ_REL, qgz_path)


def add_label(
    layout: QgsPrintLayout,
    text: str,
    x: float,
    y: float,
    width: float,
    height: float,
    size: int,
    bold: bool = False,
) -> QgsLayoutItemLabel:
    label = QgsLayoutItemLabel(layout)
    label.setText(text)
    font = QFont("Arial", size)
    font.setBold(bold)
    label.setFont(font)
    label.adjustSizeToText()
    layout.addLayoutItem(label)
    label.attemptMove(QgsLayoutPoint(x, y, QgsUnitTypes.LayoutMillimeters))
    label.attemptResize(QgsLayoutSize(width, height, QgsUnitTypes.LayoutMillimeters))
    return label


def add_map(
    layout: QgsPrintLayout,
    x: float,
    y: float,
    width: float,
    height: float,
    extent: QgsRectangle,
    layers: list[QgsVectorLayer],
) -> QgsLayoutItemMap:
    item = QgsLayoutItemMap(layout)
    item.setFrameEnabled(True)
    item.setFrameStrokeColor(QColor("#8f8f8f"))
    item.setFrameStrokeWidth(QgsLayoutMeasurement(0.2, QgsUnitTypes.LayoutMillimeters))
    layout.addLayoutItem(item)
    item.attemptMove(QgsLayoutPoint(x, y, QgsUnitTypes.LayoutMillimeters))
    item.attemptResize(QgsLayoutSize(width, height, QgsUnitTypes.LayoutMillimeters))
    item.setCrs(layers[0].crs())
    item.setLayers(layers)
    item.setKeepLayerSet(True)
    item.setExtent(extent)
    item.refresh()
    return item


def add_legend(
    layout: QgsPrintLayout,
    linked_map: QgsLayoutItemMap,
    layers: list[QgsVectorLayer],
    title: str,
    x: float,
    y: float,
    width: float,
    height: float,
) -> QgsLayoutItemLegend:
    legend = QgsLayoutItemLegend(layout)
    legend.setTitle(title)
    legend.setLinkedMap(linked_map)
    legend.setAutoUpdateModel(False)
    root = legend.model().rootGroup()
    root.removeAllChildren()
    for layer in layers:
        root.addLayer(layer)
    legend.setColumnCount(1)
    legend.setSplitLayer(True)
    legend.setStyleFont(QgsLegendStyle.Title, QFont("Arial", 8))
    legend.setStyleFont(QgsLegendStyle.SymbolLabel, QFont("Arial", 7))
    layout.addLayoutItem(legend)
    legend.attemptMove(QgsLayoutPoint(x, y, QgsUnitTypes.LayoutMillimeters))
    legend.attemptResize(QgsLayoutSize(width, height, QgsUnitTypes.LayoutMillimeters))
    return legend


# QgsLegendStyle is imported late to keep the main import list readable.
from qgis.core import QgsLegendStyle  # noqa: E402


for path in (SUBZONE_SHP, HUB_COORDS_CSV, HUB_METRICS_CSV):
    require(path)

OUTPUT_LOG.write_text("", encoding="utf-8")
for path in (TMP_GPKG, TMP_QGZ, TMP_QGZ_REL, TMP_PNG, TMP_AUDIT):
    if path.exists():
        path.unlink()

app = QgsApplication([], False)
app.initQgis()

try:
    log("FIGURE6_MAP_BUILD_STARTED")
    project_context = QgsProject.instance()

    subzones = QgsVectorLayer(str(SUBZONE_SHP), "MP2019 subzones", "ogr")
    if not subzones.isValid():
        raise RuntimeError(f"Invalid subzone layer: {SUBZONE_SHP}")
    if subzones.featureCount() != 332:
        raise RuntimeError(f"Expected 332 subzones; found {subzones.featureCount()}")
    required_subzone_fields = {"SUBZONE_C", "SUBZONE_N", "PLN_AREA_N", "REGION_N"}
    actual_subzone_fields = {field.name() for field in subzones.fields()}
    if not required_subzone_fields.issubset(actual_subzone_fields):
        raise RuntimeError("Subzone layer is missing required administrative fields")

    hub_coords = read_csv_keyed(HUB_COORDS_CSV, "pt_code_hub")
    hub_metrics = read_csv_keyed(HUB_METRICS_CSV, "hub_code")
    if len(hub_metrics) != 151:
        raise RuntimeError(f"Expected 151 pooled hubs; found {len(hub_metrics)}")
    missing_coordinates = sorted(set(hub_metrics) - set(hub_coords))
    if missing_coordinates:
        raise RuntimeError(f"Missing hub coordinates: {missing_coordinates}")

    subzone_features = list(subzones.getFeatures())
    subzone_index = QgsSpatialIndex()
    for feature in subzone_features:
        subzone_index.addFeature(feature)
    subzone_by_id = {feature.id(): feature for feature in subzone_features}
    transform = QgsCoordinateTransform(
        QgsCoordinateReferenceSystem("EPSG:4326"),
        subzones.crs(),
        project_context,
    )

    assignments: dict[str, list[dict[str, object]]] = {}
    hub_rows: list[list[object]] = []
    hub_geometries: list[QgsGeometry] = []
    for code in sorted(hub_metrics):
        coord = hub_coords[code]
        metric = hub_metrics[code]
        coverage_ratio = f(metric, "coverage_apr22_osm22_5m")
        reported_coverage_pct = f(metric, "coverage_pct")
        coverage_pct = 100 * coverage_ratio
        if abs(reported_coverage_pct - coverage_pct) > 1e-6:
            raise RuntimeError(f"Coverage definition mismatch for {code}")
        point = transform.transform(
            float(coord["hub_long"]),
            float(coord["hub_lat"]),
        )
        geometry = QgsGeometry.fromPointXY(point)
        candidate_ids = subzone_index.intersects(geometry.boundingBox())
        hits = [subzone_by_id[fid] for fid in candidate_ids if subzone_by_id[fid].geometry().intersects(geometry)]
        if len(hits) != 1:
            raise RuntimeError(f"Hub {code} matched {len(hits)} subzones")
        subzone = hits[0]
        record: dict[str, object] = {
            "hub_code": code,
            "hub_type": metric["hub_type"],
            "radius_m": i(metric, "policy_radius_m"),
            "sz_code": str(subzone["SUBZONE_C"]),
            "sz_name": str(subzone["SUBZONE_N"]),
            "coverage_pct": coverage_pct,
            "shortshare_pp": f(metric, "share_policy_r800_pp"),
            "shelter_m": f(metric, "sheltered_union_numerator_m"),
            "footway_m": f(metric, "footway_denominator_m"),
            "shortflow": i(metric, "trips_policy_r800"),
            "allflow": i(metric, "trips_all"),
        }
        if not 0 <= record["coverage_pct"] <= 100:
            raise RuntimeError(f"Coverage out of bounds for {code}")
        if not 0 <= record["shortshare_pp"] <= 100:
            raise RuntimeError(f"Short-flow share out of bounds for {code}")
        assignments.setdefault(record["sz_code"], []).append(record)
        hub_rows.append(
            [
                code,
                record["hub_type"],
                record["radius_m"],
                record["sz_code"],
                record["sz_name"],
                record["coverage_pct"],
                record["shortshare_pp"],
                record["shelter_m"],
                record["footway_m"],
                record["shortflow"],
                record["allflow"],
            ]
        )
        hub_geometries.append(geometry)

    if sum(len(rows) for rows in assignments.values()) != 151:
        raise RuntimeError("Hub-to-subzone assignment count mismatch")
    occupied_counts = [len(rows) for rows in assignments.values()]
    if len(assignments) != 113 or sum(count > 1 for count in occupied_counts) != 29:
        raise RuntimeError("Occupied or multi-hub subzone counts changed")
    if max(occupied_counts) != 4:
        raise RuntimeError("Maximum hubs per subzone changed")

    subzone_fields = [
        QgsField("sz_code", QVariant.String, len=12),
        QgsField("sz_name", QVariant.String, len=80),
        QgsField("pa_name", QVariant.String, len=80),
        QgsField("region", QVariant.String, len=40),
        QgsField("has_data", QVariant.Int),
        QgsField("n_hubs", QVariant.Int),
        QgsField("n_mrt", QVariant.Int),
        QgsField("n_mrtlrt", QVariant.Int),
        QgsField("n_lrt", QVariant.Int),
        QgsField("n_r400", QVariant.Int),
        QgsField("n_r200", QVariant.Int),
        QgsField("hub_codes", QVariant.String, len=254),
        QgsField("cov_he_pct", QVariant.Double, len=20, prec=8),
        QgsField("short_he_pp", QVariant.Double, len=20, prec=8),
        QgsField("cov_dw_pct", QVariant.Double, len=20, prec=8),
        QgsField("short_tw_pp", QVariant.Double, len=20, prec=8),
        QgsField("shelter_m", QVariant.Double, len=20, prec=6),
        QgsField("footway_m", QVariant.Double, len=20, prec=6),
        QgsField("shortflow", QVariant.LongLong),
        QgsField("allflow", QVariant.LongLong),
        QgsField("cov_gap_pp", QVariant.Double, len=20, prec=8),
        QgsField("short_gap", QVariant.Double, len=20, prec=8),
        QgsField("sample", QVariant.String, len=80),
        QgsField("radius_rule", QVariant.String, len=100),
        QgsField("cov_role", QVariant.String, len=80),
    ]
    subzone_rows: list[list[object]] = []
    subzone_geometries: list[QgsGeometry] = []
    occupied_metrics: list[dict[str, object]] = []
    for feature in subzone_features:
        code = str(feature["SUBZONE_C"])
        rows = assignments.get(code, [])
        base = [
            code,
            str(feature["SUBZONE_N"]),
            str(feature["PLN_AREA_N"]),
            str(feature["REGION_N"]),
        ]
        if rows:
            n_hubs = len(rows)
            cov_he = statistics.mean(float(row["coverage_pct"]) for row in rows)
            short_he = statistics.mean(float(row["shortshare_pp"]) for row in rows)
            shelter_m = sum(float(row["shelter_m"]) for row in rows)
            footway_m = sum(float(row["footway_m"]) for row in rows)
            shortflow = sum(int(row["shortflow"]) for row in rows)
            allflow = sum(int(row["allflow"]) for row in rows)
            if footway_m <= 0 or allflow <= 0:
                raise RuntimeError(f"Non-positive subzone denominator: {code}")
            cov_dw = 100 * shelter_m / footway_m
            short_tw = 100 * shortflow / allflow
            if not (0 <= cov_dw <= 100 and 0 <= short_tw <= 100):
                raise RuntimeError(f"Aggregated ratio out of bounds: {code}")
            values = base + [
                1,
                n_hubs,
                sum(row["hub_type"] == "MRT" for row in rows),
                sum(row["hub_type"] == "MRT/LRT" for row in rows),
                sum(row["hub_type"] == "LRT" for row in rows),
                sum(int(row["radius_m"]) == 400 for row in rows),
                sum(int(row["radius_m"]) == 200 for row in rows),
                ",".join(sorted(str(row["hub_code"]) for row in rows)),
                cov_he,
                short_he,
                cov_dw,
                short_tw,
                shelter_m,
                footway_m,
                shortflow,
                allflow,
                cov_he - cov_dw,
                short_he - short_tw,
                "MRT/MRT-LRT/LRT; 2019-03--05 and 07--12",
                "MRT and MRT/LRT: 400 m; pure LRT: 200 m",
                "Apr-2022 LTA plus 2022-01-01 OSM, 5 m match",
            ]
            occupied_metrics.append(
                {
                    "sz_code": code,
                    "n_hubs": n_hubs,
                    "cov_he": cov_he,
                    "short_he": short_he,
                    "cov_dw": cov_dw,
                    "short_tw": short_tw,
                    "shelter_m": shelter_m,
                    "footway_m": footway_m,
                    "shortflow": shortflow,
                    "allflow": allflow,
                }
            )
        else:
            values = base + [0, 0, 0, 0, 0, 0, 0, None] + [None] * 10 + [
                "MRT/MRT-LRT/LRT; 2019-03--05 and 07--12",
                "MRT and MRT/LRT: 400 m; pure LRT: 200 m",
                "Apr-2022 LTA plus 2022-01-01 OSM, 5 m match",
            ]
        if len(values) != len(subzone_fields):
            raise RuntimeError(f"Attribute-length mismatch for {code}: {len(values)}")
        subzone_rows.append(values)
        subzone_geometries.append(feature.geometry())

    hub_fields = [
        QgsField("hub_code", QVariant.String, len=30),
        QgsField("hub_type", QVariant.String, len=12),
        QgsField("radius_m", QVariant.Int),
        QgsField("sz_code", QVariant.String, len=12),
        QgsField("sz_name", QVariant.String, len=80),
        QgsField("coverage_pct", QVariant.Double, len=20, prec=8),
        QgsField("shortshare_pp", QVariant.Double, len=20, prec=8),
        QgsField("shelter_m", QVariant.Double, len=20, prec=6),
        QgsField("footway_m", QVariant.Double, len=20, prec=6),
        QgsField("shortflow", QVariant.LongLong),
        QgsField("allflow", QVariant.LongLong),
    ]

    write_memory_layer(
        "figure6_subzones",
        "MultiPolygon",
        subzones.crs().authid(),
        subzone_fields,
        subzone_rows,
        subzone_geometries,
    )
    write_memory_layer(
        "figure6_hubs",
        "Point",
        subzones.crs().authid(),
        hub_fields,
        hub_rows,
        hub_geometries,
    )
    os.replace(TMP_GPKG, OUTPUT_GPKG)
    log(f"SOURCE_GPKG_WRITTEN={OUTPUT_GPKG}")

    cov_he_values = [float(row["cov_he"]) for row in occupied_metrics]
    cov_dw_values = [float(row["cov_dw"]) for row in occupied_metrics]
    short_he_values = [float(row["short_he"]) for row in occupied_metrics]
    short_tw_values = [float(row["short_tw"]) for row in occupied_metrics]
    cov_he_breaks = quantile_breaks(cov_he_values)
    cov_dw_breaks = quantile_breaks(cov_dw_values)
    short_he_breaks = quantile_breaks(short_he_values)
    short_tw_breaks = quantile_breaks(short_tw_values)
    cov_class_changes = sum(
        quantile_class(a, cov_he_breaks) != quantile_class(b, cov_dw_breaks)
        for a, b in zip(cov_he_values, cov_dw_values)
    )
    short_class_changes = sum(
        quantile_class(a, short_he_breaks) != quantile_class(b, short_tw_breaks)
        for a, b in zip(short_he_values, short_tw_values)
    )

    audit = {
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "coverage_definition": "Apr2022_LTA_plus_OSM_20220101_5m_on_common_footway",
        "coverage_role": "backfilled descriptive proxy",
        "subzone_features": len(subzone_rows),
        "analysis_hubs": len(hub_rows),
        "occupied_subzones": len(occupied_metrics),
        "multi_hub_subzones": sum(row["n_hubs"] > 1 for row in occupied_metrics),
        "max_hubs_per_subzone": max(row["n_hubs"] for row in occupied_metrics),
        "hub_type_counts": {
            hub_type: sum(row[1] == hub_type for row in hub_rows)
            for hub_type in ("MRT", "MRT/LRT", "LRT")
        },
        "policy_radius_counts": {
            str(radius): sum(row[2] == radius for row in hub_rows)
            for radius in (200, 400)
        },
        "coverage_aggregation": {
            "equal_hub_vs_denominator_weighted_pearson": pearson(cov_he_values, cov_dw_values),
            "equal_hub_vs_denominator_weighted_spearman": spearman(cov_he_values, cov_dw_values),
            "max_absolute_gap_pp": max(abs(a - b) for a, b in zip(cov_he_values, cov_dw_values)),
            "quintile_class_changes": cov_class_changes,
        },
        "shortflow_aggregation": {
            "equal_hub_vs_trip_weighted_pearson": pearson(short_he_values, short_tw_values),
            "equal_hub_vs_trip_weighted_spearman": spearman(short_he_values, short_tw_values),
            "max_absolute_gap_pp": max(abs(a - b) for a, b in zip(short_he_values, short_tw_values)),
            "quintile_class_changes": short_class_changes,
        },
        "primary_map_fields": ["cov_he_pct", "short_he_pp"],
        "alternative_fields": ["cov_dw_pct", "short_tw_pp"],
        "unoccupied_subzone_rule": "retain polygons with null analytical values; never recode to zero",
    }
    TMP_AUDIT.write_text(json.dumps(audit, indent=2), encoding="utf-8")
    os.replace(TMP_AUDIT, OUTPUT_AUDIT)
    log(f"AUDIT_JSON_WRITTEN={OUTPUT_AUDIT}")

    # Build the editable QGIS project from the final GeoPackage path.
    project = QgsProject.instance()
    project.clear()
    try:
        project.setFilePathStorage(Qgis.FilePathType.Relative)
    except AttributeError:
        pass
    project.setTitle("Figure 6 - Spatial distribution")
    project.setCrs(subzones.crs())

    subzone_uri = f"{OUTPUT_GPKG}|layername=figure6_subzones"
    hub_uri = f"{OUTPUT_GPKG}|layername=figure6_hubs"
    base_a = QgsVectorLayer(subzone_uri, "No data (no analysis hub)", "ogr")
    coverage = QgsVectorLayer(subzone_uri, "Equal-hub sheltered coverage (%)", "ogr")
    base_b = QgsVectorLayer(subzone_uri, "No data (no analysis hub)", "ogr")
    shortflow = QgsVectorLayer(subzone_uri, "Equal-hub short-flow share (pp)", "ogr")
    hubs_a = QgsVectorLayer(hub_uri, "Analysis hubs", "ogr")
    hubs_b = QgsVectorLayer(hub_uri, "Analysis hubs", "ogr")
    for layer in (base_a, coverage, base_b, shortflow, hubs_a, hubs_b):
        if not layer.isValid():
            raise RuntimeError(f"Invalid project layer: {layer.name()}")
        set_aliases(layer)

    base_symbol = make_fill("#eeeeee", "#c2c2c2", 0.10)
    base_a.setRenderer(QgsSingleSymbolRenderer(base_symbol.clone()))
    base_b.setRenderer(QgsSingleSymbolRenderer(base_symbol.clone()))
    coverage.setSubsetString('"cov_he_pct" IS NOT NULL')
    shortflow.setSubsetString('"short_he_pp" IS NOT NULL')
    coverage_renderer, coverage_breaks = graduated_renderer(
        "cov_he_pct",
        cov_he_values,
        ["#eff3ff", "#bdd7e7", "#6baed6", "#3182bd", "#08519c"],
    )
    short_renderer, short_breaks = graduated_renderer(
        "short_he_pp",
        short_he_values,
        ["#fff5eb", "#fdd0a2", "#fdae6b", "#e6550d", "#a63603"],
    )
    coverage.setRenderer(coverage_renderer)
    shortflow.setRenderer(short_renderer)
    hub_symbol = QgsMarkerSymbol.createSimple(
        {
            "name": "circle",
            "color": "#ffffff",
            "outline_color": "#222222",
            "outline_width": "0.25",
            "size": "1.15",
        }
    )
    hubs_a.setRenderer(QgsSingleSymbolRenderer(hub_symbol.clone()))
    hubs_b.setRenderer(QgsSingleSymbolRenderer(hub_symbol.clone()))

    root = project.layerTreeRoot()
    group_a = root.addGroup("Panel a - Coverage")
    group_b = root.addGroup("Panel b - Short-distance bus flows")
    for layer, group in (
        (base_a, group_a),
        (coverage, group_a),
        (hubs_a, group_a),
        (base_b, group_b),
        (shortflow, group_b),
        (hubs_b, group_b),
    ):
        project.addMapLayer(layer, False)
        group.addLayer(layer)
    group_a.setItemVisibilityChecked(True)
    group_b.setItemVisibilityChecked(False)

    layout = QgsPrintLayout(project)
    layout.initializeDefaults()
    layout.setName("Figure 6 - Two-panel spatial distribution")
    page = layout.pageCollection().page(0)
    page.setPageSize(QgsLayoutSize(297, 210, QgsUnitTypes.LayoutMillimeters))
    project.layoutManager().addLayout(layout)

    add_label(
        layout,
        "Spatial Distribution of Sheltered-Walkway Coverage and Short-Distance Feeder-Bus Flows",
        8,
        4,
        281,
        9,
        14,
        True,
    )
    add_label(layout, "a. Mean sheltered-footway coverage across hubs", 8, 15, 136, 7, 10, True)
    add_label(layout, "b. Mean short-distance feeder-bus flow share across hubs", 153, 15, 136, 7, 10, True)

    extent = base_a.extent()
    if extent.isEmpty() or extent.width() <= 0 or extent.height() <= 0:
        raise RuntimeError(f"Invalid map extent: {extent.toString()}")
    log(f"MAP_EXTENT={extent.toString()}")
    x_pad = extent.width() * 0.025
    y_pad = extent.height() * 0.025
    map_extent = QgsRectangle(
        extent.xMinimum() - x_pad,
        extent.yMinimum() - y_pad,
        extent.xMaximum() + x_pad,
        extent.yMaximum() + y_pad,
    )
    map_a = add_map(layout, 8, 24, 136, 112, map_extent, [hubs_a, coverage, base_a])
    map_b = add_map(layout, 153, 24, 136, 112, map_extent, [hubs_b, shortflow, base_b])
    add_legend(layout, map_a, [coverage, base_a], "Coverage within applicable policy radius (%)", 8, 139, 136, 44)
    add_legend(layout, map_b, [shortflow, base_b], "Policy-area route<=800 m share (percentage points)", 153, 139, 136, 44)
    add_label(
        layout,
        "Notes: Subzone values are equal-hub means. MRT and MRT/LRT hubs use 400 m; pure LRT hubs use 200 m. "
        "Bus shares pool March–May and July–December 2019 farecard flows at each hub before subzone averaging. "
        "Grey subzones contain no analysis hub. Coverage uses Apr-2022 LTA polygons plus 2022-01-01 OSM covered ways, matched at 5 m to the available fallback footway network.",
        8,
        196,
        281,
        10,
        7,
        False,
    )

    if not project.write(str(TMP_QGZ)):
        raise RuntimeError("Failed to write QGIS project")
    relativize_qgz(TMP_QGZ, OUTPUT_GPKG)
    os.replace(TMP_QGZ, OUTPUT_QGZ)
    log(f"QGIS_PROJECT_WRITTEN={OUTPUT_QGZ}")

    exporter = QgsLayoutExporter(layout)
    image_settings = QgsLayoutExporter.ImageExportSettings()
    image_settings.dpi = 120
    png_result = exporter.exportToImage(str(TMP_PNG), image_settings)
    if png_result != QgsLayoutExporter.Success:
        raise RuntimeError(f"PNG export failed: {png_result}")
    os.replace(TMP_PNG, OUTPUT_PNG)
    log(f"PREVIEW_PNG_WRITTEN={OUTPUT_PNG}")

    # Reopen both deliverables after writing to verify their portable interface.
    check_subzones = QgsVectorLayer(
        f"{OUTPUT_GPKG}|layername=figure6_subzones", "check_subzones", "ogr"
    )
    check_hubs = QgsVectorLayer(
        f"{OUTPUT_GPKG}|layername=figure6_hubs", "check_hubs", "ogr"
    )
    if not check_subzones.isValid() or check_subzones.featureCount() != 332:
        raise RuntimeError("GeoPackage subzone layer failed reopen QA")
    if not check_hubs.isValid() or check_hubs.featureCount() != 151:
        raise RuntimeError("GeoPackage hub layer failed reopen QA")
    check_project = QgsProject()
    if not check_project.read(str(OUTPUT_QGZ)):
        raise RuntimeError("QGZ failed reopen QA")
    invalid_layers = [layer.name() for layer in check_project.mapLayers().values() if not layer.isValid()]
    if invalid_layers:
        raise RuntimeError(f"QGZ has invalid layers after reopen: {invalid_layers}")
    if len(check_project.mapLayers()) != 6:
        raise RuntimeError(f"Expected 6 QGZ layers; found {len(check_project.mapLayers())}")
    if len(check_project.layoutManager().layouts()) != 1:
        raise RuntimeError("Expected one QGIS Print Layout")
    if sum(layer.name() == "No data (no analysis hub)" for layer in check_project.mapLayers().values()) != 2:
        raise RuntimeError("Expected one no-data legend layer per panel")
    log("PORTABLE_REOPEN_QA=PASS")
    log("COVERAGE_PALETTE=LIGHT_TO_DARK_BLUE")
    log("NO_DATA_LEGEND_CATEGORY=PASS")
    log(f"COVERAGE_QUINTILE_BREAKS={coverage_breaks}")
    log(f"SHORTFLOW_QUINTILE_BREAKS={short_breaks}")
    log("FIGURE6_MAP_BUILD_COMPLETE")
finally:
    # Explicit exitQgis() can segfault after successful headless macOS exports.
    log("QGIS processing block finished")
