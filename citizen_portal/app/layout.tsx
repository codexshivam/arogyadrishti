import React from "react";

export const metadata = {
  title:
    "नागरिक पारदर्शिता पोर्टल | Citizen Transparency Portal — Government of Nepal (citizen.nidaniq.com.np)",
  description:
    "Read-only, Zero-Citizen-PII public dengue surveillance dashboard for Nepal Palikas & Wards (Individual Privacy Act 2075 compliant).",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ne">
      <body
        style={{
          margin: 0,
          fontFamily: "'Noto Sans Devanagari', 'Inter', system-ui, sans-serif",
          background: "#F8FAFC",
          color: "#0F172A",
        }}
      >
        {children}
      </body>
    </html>
  );
}
