"use client";

import React, { useEffect, useRef } from "react";
import * as maplibregl from "maplibre-gl";

interface WardMapLibreViewProps {
  compositeWardId: string;
  palikaCode: string;
  boundingBox: [number, number, number, number]; // [minLng, minLat, maxLng, maxLat]
  riskTier: string;
}

/**
 * Dynamic MapLibre GL Component (`WardMapLibreView.tsx`)
 * - Loads national PostGIS `ST_AsMVT` vector tiles (`/api/v1/gis/tiles/{z}/{x}/{y}.mvt`).
 * - Dynamically calls `map.fitBounds()` to zoom and highlight the polygon of the resolved Palika/Ward.
 */
export default function WardMapLibreView({
  compositeWardId,
  palikaCode,
  boundingBox,
  riskTier,
}: WardMapLibreViewProps) {
  const mapContainerRef = useRef<HTMLDivElement | null>(null);
  const mapInstanceRef = useRef<maplibregl.Map | null>(null);

  useEffect(() => {
    if (!mapContainerRef.current) return;

    const tileUrl = `/api/v1/gis/tiles/{z}/{x}/{y}.mvt?palika_code=${encodeURIComponent(
      palikaCode
    )}&composite_ward_id=${encodeURIComponent(compositeWardId)}`;

    const map = new maplibregl.Map({
      container: mapContainerRef.current,
      style: {
        version: 8,
        sources: {
          "nepal-wards-mvt": {
            type: "vector",
            tiles: [
              tileUrl,
              `/api/v1/tiles/wards/{z}/{x}/{y}.mvt?palika_code=${encodeURIComponent(
                palikaCode
              )}`,
            ],
            minzoom: 5,
            maxzoom: 16,
          },
        },
        layers: [
          {
            id: "nepal-wards-base-fill",
            type: "fill",
            source: "nepal-wards-mvt",
            "source-layer": "wards",
            paint: {
              "fill-color": "#94A3B8",
              "fill-opacity": 0.22,
            },
          },
          {
            id: "resolved-ward-highlight-fill",
            type: "fill",
            source: "nepal-wards-mvt",
            "source-layer": "wards",
            filter: ["==", ["get", "composite_ward_id"], compositeWardId],
            paint: {
              "fill-color":
                riskTier.startsWith("CRITICAL") || riskTier === "HIGH"
                  ? "#DC2626"
                  : "#10B981",
              "fill-opacity": 0.45,
            },
          },
          {
            id: "resolved-ward-highlight-outline",
            type: "line",
            source: "nepal-wards-mvt",
            "source-layer": "wards",
            filter: ["==", ["get", "composite_ward_id"], compositeWardId],
            paint: {
              "line-color": "#0B3D91",
              "line-width": 3,
            },
          },
        ],
      },
      bounds: boundingBox,
      fitBoundsOptions: { padding: 48 },
    });

    mapInstanceRef.current = map;

    map.on("load", () => {
      map.fitBounds(
        [
          [boundingBox[0], boundingBox[1]],
          [boundingBox[2], boundingBox[3]],
        ],
        { padding: 48, duration: 1200 }
      );
    });

    return () => {
      map.remove();
      mapInstanceRef.current = null;
    };
  }, [compositeWardId, palikaCode, boundingBox, riskTier]);

  return (
    <section
      aria-label="Dynamic Ward MapLibre GL ST_AsMVT Vector Map"
      style={{
        border: "1px solid #CBD5E1",
        borderRadius: "14px",
        overflow: "hidden",
        background: "#F8FAFC",
      }}
    >
      <div
        style={{
          padding: "10px 16px",
          background: "#0F172A",
          color: "#FFFFFF",
          fontSize: "0.84rem",
          display: "flex",
          justifyContent: "space-between",
        }}
      >
        <span>
          PostGIS ST_AsMVT Vector Tiles:{" "}
          <code>/api/v1/gis/tiles/&#123;z&#125;/&#123;x&#125;/&#123;y&#125;.mvt</code>
        </span>
        <span>
          Active Ward Polygon: <strong>{compositeWardId}</strong> (map.fitBounds)
        </span>
      </div>
      <div
        ref={mapContainerRef}
        id="ward-maplibre-canvas"
        style={{ width: "100%", height: "380px" }}
      />
    </section>
  );
}
