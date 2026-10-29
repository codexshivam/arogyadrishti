"use client";

import React, { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";

export interface WardHierarchyOption {
  composite_ward_id: string;
  ward_no: number;
  locality_name: string;
  locality_name_np: string;
  palika_code: string;
  palika_name: string;
  palika_name_np: string;
  district_code: number;
  district_name: string;
  district_name_np: string;
  province_code: number;
  province_name: string;
  province_name_np: string;
}

export const NEPAL_WARD_HIERARCHY: WardHierarchyOption[] = [
  {
    composite_ward_id: "NP-P3-D27-30608-W17",
    ward_no: 17,
    locality_name: "Chhetrapati",
    locality_name_np: "क्षेत्रपाटी",
    palika_code: "30608",
    palika_name: "Kathmandu Metro",
    palika_name_np: "काठमाडौँ महानगरपालिका",
    district_code: 27,
    district_name: "Kathmandu",
    district_name_np: "काठमाडौँ",
    province_code: 3,
    province_name: "Bagmati Province",
    province_name_np: "बागमती प्रदेश",
  },
  {
    composite_ward_id: "NP-P3-D27-30608-W16",
    ward_no: 16,
    locality_name: "Balaju",
    locality_name_np: "बालाजु",
    palika_code: "30608",
    palika_name: "Kathmandu Metro",
    palika_name_np: "काठमाडौँ महानगरपालिका",
    district_code: 27,
    district_name: "Kathmandu",
    district_name_np: "काठमाडौँ",
    province_code: 3,
    province_name: "Bagmati Province",
    province_name_np: "बागमती प्रदेश",
  },
  {
    composite_ward_id: "NP-P3-D28-30805-W05",
    ward_no: 5,
    locality_name: "Lagankhel / Patan",
    locality_name_np: "लगनखेल / पाटन",
    palika_code: "30805",
    palika_name: "Lalitpur Metro",
    palika_name_np: "ललितपुर महानगरपालिका",
    district_code: 28,
    district_name: "Lalitpur",
    district_name_np: "ललितपुर",
    province_code: 3,
    province_name: "Bagmati Province",
    province_name_np: "बागमती प्रदेश",
  },
  {
    composite_ward_id: "NP-P3-D35-30902-W10",
    ward_no: 10,
    locality_name: "Hospital Road / Hakim Chowk",
    locality_name_np: "अस्पताल रोड / हाकिम चोक",
    palika_code: "30902",
    palika_name: "Bharatpur Metro",
    palika_name_np: "भरतपुर महानगरपालिका",
    district_code: 35,
    district_name: "Chitwan",
    district_name_np: "चितवन",
    province_code: 3,
    province_name: "Bagmati Province",
    province_name_np: "बागमती प्रदेश",
  },
  {
    composite_ward_id: "NP-P4-D40-40307-W06",
    ward_no: 6,
    locality_name: "Baidam (Lakeside)",
    locality_name_np: "बैदाम (लेकसाइड)",
    palika_code: "40307",
    palika_name: "Pokhara Metro",
    palika_name_np: "पोखरा महानगरपालिका",
    district_code: 40,
    district_name: "Kaski",
    district_name_np: "कास्की",
    province_code: 4,
    province_name: "Gandaki Province",
    province_name_np: "गण्डकी प्रदेश",
  },
  {
    composite_ward_id: "NP-P1-D05-10403-W07",
    ward_no: 7,
    locality_name: "Haatkhola",
    locality_name_np: "हाटखोला",
    palika_code: "10403",
    palika_name: "Biratnagar Metro",
    palika_name_np: "विराटनगर महानगरपालिका",
    district_code: 5,
    district_name: "Morang",
    district_name_np: "मोरङ",
    province_code: 1,
    province_name: "Koshi Province",
    province_name_np: "कोशी प्रदेश",
  },
  {
    composite_ward_id: "NP-P6-D64-60903-W06",
    ward_no: 6,
    locality_name: "Birendranagar Bazaar",
    locality_name_np: "वीरेन्द्रनगर बजार",
    palika_code: "60903",
    palika_name: "Birendranagar Municipality",
    palika_name_np: "वीरेन्द्रनगर नगरपालिका",
    district_code: 64,
    district_name: "Surkhet",
    district_name_np: "सुर्खेत",
    province_code: 6,
    province_name: "Karnali Province",
    province_name_np: "कर्णाली प्रदेश",
  },
];

interface LocationContextHeaderProps {
  currentCompositeWardId?: string;
  palikaName?: string;
  palikaNameNp?: string;
  wardNo?: number;
  autoResolveBrowserGps?: boolean;
}

/**
 * Location Context Navbar Button & Bilingual Cascading Modal (`Province -> District -> Palika -> Ward`).
 * Uses Browser Geolocation API (`navigator.geolocation`) on initial load when no ward is resolved,
 * and enforces strict **Zero Defaulting** ("Select Your Palika") if GPS is denied.
 */
export default function LocationContextHeader({
  currentCompositeWardId,
  palikaName,
  palikaNameNp,
  wardNo,
  autoResolveBrowserGps = false,
}: LocationContextHeaderProps) {
  const router = useRouter();
  const [isModalOpen, setIsModalOpen] = useState<boolean>(!currentCompositeWardId);
  const [gpsStatus, setGpsStatus] = useState<string>("");

  const activeEntry = useMemo(
    () =>
      NEPAL_WARD_HIERARCHY.find(
        (w) => w.composite_ward_id === currentCompositeWardId
      ) ?? NEPAL_WARD_HIERARCHY[2], // Default modal cursor on Lalitpur W5 until user confirms
    [currentCompositeWardId]
  );

  const [provinceCode, setProvinceCode] = useState<number>(
    activeEntry.province_code
  );
  const [districtCode, setDistrictCode] = useState<number>(
    activeEntry.district_code
  );
  const [palikaCode, setPalikaCode] = useState<string>(activeEntry.palika_code);
  const [selectedWardId, setSelectedWardId] = useState<string>(
    activeEntry.composite_ward_id
  );

  const resolveViaBrowserGeolocation = () => {
    if (typeof window === "undefined" || !("geolocation" in navigator)) {
      setGpsStatus("Geolocation unavailable. Please Select Your Palika below.");
      setIsModalOpen(true);
      return;
    }
    setGpsStatus("Resolving coordinates via PostGIS ST_Contains...");
    navigator.geolocation.getCurrentPosition(
      async (position) => {
        try {
          const { latitude, longitude } = position.coords;
          const res = await fetch(
            `/api/v1/spatial/resolve?lat=${latitude}&lng=${longitude}`
          );
          if (!res.ok) {
            setGpsStatus("Outside resolvable boundary — Select Your Palika.");
            setIsModalOpen(true);
            return;
          }
          const data = await res.json();
          if (data?.composite_ward_id) {
            setIsModalOpen(false);
            router.push(`/ward/${data.composite_ward_id}`);
          }
        } catch {
          setGpsStatus("Network error — Select Your Palika manually.");
          setIsModalOpen(true);
        }
      },
      () => {
        // Zero Defaulting: Never default to Kathmandu if GPS is denied
        setGpsStatus(
          "GPS permission denied. Zero Defaulting Policy: Please Select Your Palika."
        );
        setIsModalOpen(true);
      },
      { enableHighAccuracy: true, timeout: 8000 }
    );
  };

  useEffect(() => {
    if (autoResolveBrowserGps && !currentCompositeWardId) {
      resolveViaBrowserGeolocation();
    }
  }, [autoResolveBrowserGps, currentCompositeWardId]);

  const provinces = useMemo(() => {
    const map = new Map<number, { code: number; label: string }>();
    for (const w of NEPAL_WARD_HIERARCHY) {
      map.set(w.province_code, {
        code: w.province_code,
        label: w.province_name,
      });
    }
    return Array.from(map.values());
  }, []);

  const districts = useMemo(() => {
    const map = new Map<number, { code: number; label: string }>();
    for (const w of NEPAL_WARD_HIERARCHY) {
      if (w.province_code === provinceCode) {
        map.set(w.district_code, {
          code: w.district_code,
          label: w.district_name,
        });
      }
    }
    return Array.from(map.values());
  }, [provinceCode]);

  const palikas = useMemo(() => {
    const map = new Map<string, { code: string; label: string }>();
    for (const w of NEPAL_WARD_HIERARCHY) {
      if (
        w.province_code === provinceCode &&
        w.district_code === districtCode
      ) {
        map.set(w.palika_code, {
          code: w.palika_code,
          label: w.palika_name,
        });
      }
    }
    return Array.from(map.values());
  }, [provinceCode, districtCode]);

  const wards = useMemo(
    () =>
      NEPAL_WARD_HIERARCHY.filter(
        (w) =>
          w.province_code === provinceCode &&
          w.district_code === districtCode &&
          w.palika_code === palikaCode
      ),
    [provinceCode, districtCode, palikaCode]
  );

  const buttonLabel = currentCompositeWardId
    ? `📍 ${palikaName ?? activeEntry.palika_name}, Ward ${
        wardNo ?? activeEntry.ward_no
      }`
    : "📍 Select Your Palika & Ward";

  return (
    <>
      <header
        style={{
          background: "#0B3D91",
          color: "#FFFFFF",
          padding: "14px 24px",
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          flexWrap: "wrap",
          gap: "12px",
        }}
      >
        <div>
          <strong style={{ fontSize: "1.05rem" }}>
            NidanIQ • Citizen Transparency Portal
          </strong>
          <div style={{ fontSize: "0.82rem", opacity: 0.9 }}>
            Predictive Vector Surveillance & Outbreak Intelligence
          </div>
        </div>
        <div style={{ display: "flex", gap: "10px", alignItems: "center" }}>
          <button
            id="location-context-navbar-button"
            type="button"
            onClick={() => setIsModalOpen(true)}
            style={{
              background: "#FFFFFF",
              color: "#0B3D91",
              border: "2px solid #93C5FD",
              borderRadius: "999px",
              padding: "8px 16px",
              fontWeight: 700,
              cursor: "pointer",
            }}
          >
            {buttonLabel}
          </button>
          <button
            id="browser-geolocation-resolve-button"
            type="button"
            onClick={resolveViaBrowserGeolocation}
            style={{
              background: "#10B981",
              color: "#FFFFFF",
              border: "none",
              borderRadius: "999px",
              padding: "8px 14px",
              fontWeight: 700,
              cursor: "pointer",
            }}
          >
            Use GPS Location
          </button>
        </div>
      </header>

      {isModalOpen && (
        <div
          id="select-your-palika-modal"
          role="dialog"
          aria-modal="true"
          aria-labelledby="select-palika-title"
          style={{
            position: "fixed",
            inset: 0,
            background: "rgba(15, 23, 42, 0.65)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            zIndex: 1000,
            padding: "16px",
          }}
        >
          <div
            style={{
              background: "#FFFFFF",
              borderRadius: "16px",
              maxWidth: "520px",
              width: "100%",
              padding: "24px",
              boxShadow: "0 20px 45px rgba(15, 23, 42, 0.25)",
            }}
          >
            <h2 id="select-palika-title" style={{ marginTop: 0 }}>
              Select Your Municipality &amp; Ward
            </h2>
            <p style={{ fontSize: "0.88rem", color: "#475569" }}>
              Choose your administrative boundary or use Browser Geolocation.
            </p>
            {gpsStatus && (
              <div
                style={{
                  background: "#EFF6FF",
                  color: "#1E3A8A",
                  padding: "8px 12px",
                  borderRadius: "8px",
                  marginBottom: "12px",
                  fontSize: "0.84rem",
                }}
              >
                {gpsStatus}
              </div>
            )}

            <label style={{ display: "block", marginBottom: "10px" }}>
              <span style={{ fontWeight: 700, fontSize: "0.85rem" }}>
                1. Province
              </span>
              <select
                value={provinceCode}
                onChange={(e) => {
                  const nextProv = Number(e.target.value);
                  const first = NEPAL_WARD_HIERARCHY.find(
                    (w) => w.province_code === nextProv
                  );
                  setProvinceCode(nextProv);
                  if (first) {
                    setDistrictCode(first.district_code);
                    setPalikaCode(first.palika_code);
                    setSelectedWardId(first.composite_ward_id);
                  }
                }}
                style={{ width: "100%", padding: "8px", marginTop: "4px" }}
              >
                {provinces.map((p) => (
                  <option key={p.code} value={p.code}>
                    {p.label}
                  </option>
                ))}
              </select>
            </label>

            <label style={{ display: "block", marginBottom: "10px" }}>
              <span style={{ fontWeight: 700, fontSize: "0.85rem" }}>
                2. District
              </span>
              <select
                value={districtCode}
                onChange={(e) => {
                  const nextDist = Number(e.target.value);
                  const first = NEPAL_WARD_HIERARCHY.find(
                    (w) =>
                      w.province_code === provinceCode &&
                      w.district_code === nextDist
                  );
                  setDistrictCode(nextDist);
                  if (first) {
                    setPalikaCode(first.palika_code);
                    setSelectedWardId(first.composite_ward_id);
                  }
                }}
                style={{ width: "100%", padding: "8px", marginTop: "4px" }}
              >
                {districts.map((d) => (
                  <option key={d.code} value={d.code}>
                    {d.label}
                  </option>
                ))}
              </select>
            </label>

            <label style={{ display: "block", marginBottom: "10px" }}>
              <span style={{ fontWeight: 700, fontSize: "0.85rem" }}>
                3. Palika (Municipality)
              </span>
              <select
                value={palikaCode}
                onChange={(e) => {
                  const nextPalika = e.target.value;
                  const first = NEPAL_WARD_HIERARCHY.find(
                    (w) => w.palika_code === nextPalika
                  );
                  setPalikaCode(nextPalika);
                  if (first) {
                    setSelectedWardId(first.composite_ward_id);
                  }
                }}
                style={{ width: "100%", padding: "8px", marginTop: "4px" }}
              >
                {palikas.map((p) => (
                  <option key={p.code} value={p.code}>
                    {p.label}
                  </option>
                ))}
              </select>
            </label>

            <label style={{ display: "block", marginBottom: "16px" }}>
              <span style={{ fontWeight: 700, fontSize: "0.85rem" }}>
                4. Ward Number
              </span>
              <select
                value={selectedWardId}
                onChange={(e) => setSelectedWardId(e.target.value)}
                style={{ width: "100%", padding: "8px", marginTop: "4px" }}
              >
                {wards.map((w) => (
                  <option key={w.composite_ward_id} value={w.composite_ward_id}>
                    Ward {w.ward_no} — {w.locality_name}
                  </option>
                ))}
              </select>
            </label>

            <div style={{ display: "flex", gap: "10px" }}>
              <button
                type="button"
                onClick={() => {
                  setIsModalOpen(false);
                  router.push(`/ward/${selectedWardId}`);
                }}
                style={{
                  flex: 1,
                  background: "#0B3D91",
                  color: "#FFFFFF",
                  border: "none",
                  borderRadius: "8px",
                  padding: "10px 16px",
                  fontWeight: 700,
                  cursor: "pointer",
                }}
              >
                Open Ward Dashboard
              </button>
              {currentCompositeWardId && (
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  style={{
                    background: "#E2E8F0",
                    color: "#0F172A",
                    border: "none",
                    borderRadius: "8px",
                    padding: "10px 14px",
                    cursor: "pointer",
                  }}
                >
                  Close
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </>
  );
}
