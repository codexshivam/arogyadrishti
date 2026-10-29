import React from "react";

export const metadata = {
  title:
    "Citizen Transparency Portal — NidanIQ Vector Surveillance DPI",
  description:
    "Read-only public vector surveillance dashboard for municipal wards.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body
        style={{
          margin: 0,
          fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
          background: "#F8FAFC",
          color: "#0F172A",
        }}
      >
        {children}
      </body>
    </html>
  );
}
