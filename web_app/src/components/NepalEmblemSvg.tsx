import React from 'react';

interface NepalEmblemProps {
  className?: string;
  size?: number;
}

export const NepalEmblemSvg: React.FC<NepalEmblemProps> = ({ className = '', size = 56 }) => {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 200 200"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-label="Government of Nepal Emblem"
    >
      {/* Outer Wreath - Rhododendron Garland (Red & Green) */}
      <circle cx="100" cy="95" r="88" stroke="#C8102E" strokeWidth="8" strokeDasharray="6 4" fill="#FDF2F4" />
      <circle cx="100" cy="95" r="76" stroke="#107C41" strokeWidth="4" fill="#FFFFFF" />

      {/* Himalayan Mountain Range Silhouette */}
      <path
        d="M40 120 L75 75 L100 100 L130 65 L160 120 Z"
        fill="#EBF3FC"
        stroke="#1B4D9B"
        strokeWidth="3"
        strokeLinejoin="round"
      />
      {/* Snow Caps */}
      <polygon points="75,75 85,90 65,90" fill="#FFFFFF" />
      <polygon points="130,65 142,85 118,85" fill="#FFFFFF" />

      {/* Green Rolling Hills / Terai Valley */}
      <path
        d="M36 120 C50 105, 80 105, 100 120 C120 105, 150 105, 164 120 L164 135 L36 135 Z"
        fill="#107C41"
      />

      {/* Equality Handshake (Symbol of Unity) */}
      <g transform="translate(76, 122) scale(0.9)">
        <rect x="2" y="5" width="22" height="12" rx="4" fill="#F6C343" stroke="#9E0B23" strokeWidth="1.5" />
        <rect x="26" y="5" width="22" height="12" rx="4" fill="#F6C343" stroke="#9E0B23" strokeWidth="1.5" />
        <path d="M18 11 L32 11" stroke="#9E0B23" strokeWidth="2" strokeLinecap="round" />
      </g>

      {/* Yellow Paddy Ears Garland */}
      <path
        d="M34 95 Q38 135 60 155"
        stroke="#C28B10"
        strokeWidth="5"
        fill="none"
        strokeLinecap="round"
      />
      <path
        d="M166 95 Q162 135 140 155"
        stroke="#C28B10"
        strokeWidth="5"
        fill="none"
        strokeLinecap="round"
      />

      {/* National Red Ribbon Banner */}
      <path
        d="M20 162 L50 152 L150 152 L180 162 L170 178 L145 168 L55 168 L30 178 Z"
        fill="#C8102E"
        stroke="#9E0B23"
        strokeWidth="2"
      />

      {/* Motto / Star */}
      <circle cx="100" cy="46" r="6" fill="#C8102E" stroke="#FFFFFF" strokeWidth="1.5" />
      <path
        d="M100 34 L103 42 L111 42 L105 47 L107 55 L100 50 L93 55 L95 47 L89 42 L97 42 Z"
        fill="#C8102E"
      />

      {/* Banner Label Text */}
      <text
        x="100"
        y="163"
        fill="#FFFFFF"
        fontSize="8"
        fontWeight="bold"
        textAnchor="middle"
        fontFamily="Noto Sans Devanagari, sans-serif"
      >
        जननी जन्मभूमिश्च स्वर्गादपि गरीयसी
      </text>
    </svg>
  );
};
