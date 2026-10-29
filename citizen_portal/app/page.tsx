import React from "react";
import LocationContextHeader from "../components/LocationContextHeader";

/**
 * Root Landing Page (`citizen_portal/app/page.tsx`)
 * - Automatically invokes Browser Geolocation (`navigator.geolocation`) via `LocationContextHeader`.
 * - Enforces **Zero Defaulting**: if GPS is denied or pending, prompts the user with the
 *   "Select Your Palika" (`Province -> District -> Palika -> Ward`) onboarding modal instead of
 *   silently defaulting to Kathmandu.
 */
export default function CitizenPortalLandingPage() {
  return (
    <main>
      <LocationContextHeader autoResolveBrowserGps={true} />
      <section style={{ maxWidth: "960px", margin: "32px auto", padding: "0 20px" }}>
        <div
          style={{
            background: "#FFFFFF",
            borderRadius: "16px",
            border: "1px solid #CBD5E1",
            padding: "28px",
          }}
        >
          <h1 style={{ marginTop: 0 }}>
            Select Your Municipal Ward
          </h1>
          <p style={{ color: "#475569", lineHeight: 1.6 }}>
            Welcome to the NidanIQ Vector Surveillance Citizen Transparency Portal
            (<code>citizen.nidaniq.com.np</code>).
            To view localized epidemiological intelligence, select your exact{" "}
            <strong>Province -&gt; District -&gt; Palika -&gt; Ward</strong>{" "}
            using the Location Context selector above or enable Browser Geolocation.
          </p>
        </div>
      </section>
    </main>
  );
}
