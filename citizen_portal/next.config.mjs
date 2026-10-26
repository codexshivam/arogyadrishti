/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  async headers() {
    return [
      {
        source: "/ward/:composite_ward_id*",
        headers: [
          {
            key: "Cache-Control",
            value: "public, s-maxage=900, stale-while-revalidate=60",
          },
          {
            key: "X-Privacy-Compliance",
            value: "Nepal Individual Privacy Act 2075 (Zero Citizen PII)",
          },
        ],
      },
    ];
  },
};

export default nextConfig;
