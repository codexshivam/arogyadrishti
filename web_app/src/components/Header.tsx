import React from 'react';
import { useAuth } from '../context/AuthContext';
import { LogOut, Shield, MapPin, Phone, Activity } from 'lucide-react';

export const Header: React.FC = () => {
  const { currentUser, logout } = useAuth();

  const getRoleLabel = (role?: string) => {
    switch (role) {
      case 'admin':
        return 'System Administrator';
      case 'municipality_admin':
        return 'Municipality Administrator';
      case 'field_visitor':
        return 'Field Surveillance Officer';
      case 'fchv':
        return 'FCHV';
      case 'ward_health_officer':
        return 'Ward Health Officer';
      case 'palika_health_chief':
        return 'Palika Health Chief';
      case 'edcd_nodal':
        return 'EDCD Nodal Officer';
      default:
        return 'Health Staff';
    }
  };

  const getRoleBadgeStyle = (role?: string) => {
    switch (role) {
      case 'admin':
        return 'bg-[#fee2e2] text-[#991b1b] border-[#fecaca]';
      case 'municipality_admin':
        return 'bg-[#e0e7ff] text-[#4338ca] border-[#c7d2fe]';
      default:
        return 'bg-[#dcfce7] text-[#166534] border-[#bbf7d0]';
    }
  };

  return (
    <header className="bg-white border-b border-[#e2e8f0] sticky top-0 z-50 shadow-2xs">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
          {/* Left: NidanIQ Logo & Identity */}
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-xl bg-linear-to-tr from-[#7c0012] to-[#a50c1f] flex items-center justify-center text-white shadow-md shadow-[#a50c1f]/25 shrink-0">
              <Activity className="w-6 h-6" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <span className="text-xl font-bold tracking-tight text-[#0f172a]">
                  Nidan<span className="text-[#a50c1f]">IQ</span>
                </span>
                <span className="bg-[#fee2e2] text-[#991b1b] text-[10px] font-bold px-2 py-0.5 rounded-full uppercase tracking-wider">
                  Surveillance DPI
                </span>
              </div>
              <p className="text-xs text-[#64748b] font-medium">
                Predictive Vector Surveillance & Outbreak Intelligence
              </p>
            </div>
          </div>

          {/* Right: Authenticated User Information & Sign Out */}
          {currentUser && (
            <div className="flex items-center space-x-3 justify-end flex-wrap gap-y-2">
              <div className="flex items-center space-x-2.5 bg-[#f8fafc] border border-[#e2e8f0] rounded-xl px-3 py-1.5 text-xs">
                <div className="w-7 h-7 rounded-full bg-[#dae2fd] text-[#131b2e] flex items-center justify-center font-bold shrink-0">
                  {currentUser.full_name.charAt(0) || 'U'}
                </div>
                <div className="text-left">
                  <div className="font-semibold text-[#0f172a] flex items-center gap-1.5">
                    <span>{currentUser.full_name}</span>
                    <span className={`text-[10px] font-bold px-1.5 py-0.2 rounded-full border ${getRoleBadgeStyle(currentUser.role)}`}>
                      {getRoleLabel(currentUser.role)}
                    </span>
                  </div>
                  <div className="text-[11px] text-[#64748b] flex items-center gap-2">
                    <span className="flex items-center gap-1">
                      <Phone className="w-3 h-3 text-[#64748b]" />
                      {currentUser.phone}
                    </span>
                    {currentUser.palika_code && (
                      <span className="flex items-center gap-1">
                        <MapPin className="w-3 h-3 text-[#64748b]" />
                        Palika: {currentUser.palika_code}
                      </span>
                    )}
                  </div>
                </div>
              </div>

              <button
                type="button"
                onClick={logout}
                className="inline-flex items-center space-x-1.5 px-3 py-1.5 rounded-lg border border-[#cbd5e1] text-xs font-semibold text-[#334155] hover:text-[#991b1b] hover:bg-[#fee2e2]/50 hover:border-[#fca5a5] transition-colors"
                title="Sign Out"
              >
                <LogOut className="w-3.5 h-3.5" />
                <span>Sign Out</span>
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Sub-Banner: Scoped Jurisdiction */}
      {currentUser && (
        <div className="bg-[#191c1e] text-white text-[11px] font-medium py-1.5 px-4 sm:px-6 lg:px-8 border-t border-[#2d3133]">
          <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <Shield className="w-3.5 h-3.5 text-[#ffb1ad] shrink-0" />
              <span>
                Active Jurisdiction:{' '}
                <strong className="text-white">
                  {currentUser.role === 'admin'
                    ? 'Federal Authority (All Municipalities & Wards)'
                    : `Palika Code: ${currentUser.palika_code} (${currentUser.assigned_wards.includes('*') ? 'All Municipal Wards' : `Wards: ${currentUser.assigned_wards.join(', ')}`})`}
                </strong>
              </span>
            </div>
            <div className="text-[#a0a4a8] text-[10px] font-mono">
              Session Secured • EdDSA Bearer Token
            </div>
          </div>
        </div>
      )}
    </header>
  );
};
