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
        return 'bg-purple-50 text-purple-700 border-purple-200';
      case 'municipality_admin':
        return 'bg-blue-50 text-blue-700 border-blue-200';
      default:
        return 'bg-emerald-50 text-emerald-700 border-emerald-200';
    }
  };

  return (
    <header className="bg-white border-b border-slate-200 sticky top-0 z-50 shadow-xs">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
          {/* Left: NidanIQ Logo & Identity */}
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-xl bg-linear-to-tr from-blue-600 to-indigo-600 flex items-center justify-center text-white shadow-md shadow-blue-500/20 shrink-0">
              <Activity className="w-6 h-6" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <span className="text-xl font-black tracking-tight text-slate-900">
                  Nidan<span className="text-blue-600">IQ</span>
                </span>
                <span className="bg-blue-100 text-blue-800 text-[10px] font-bold px-2 py-0.5 rounded-full uppercase tracking-wider">
                  Operational DPI
                </span>
              </div>
              <p className="text-xs text-slate-500 font-medium">
                Predictive Vector Surveillance & Outbreak Intelligence Platform
              </p>
            </div>
          </div>

          {/* Right: Authenticated User Information & Sign Out */}
          {currentUser && (
            <div className="flex items-center space-x-3 justify-end flex-wrap gap-y-2">
              <div className="flex items-center space-x-2.5 bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-xs">
                <div className="w-7 h-7 rounded-full bg-slate-200 flex items-center justify-center text-slate-700 font-bold shrink-0">
                  {currentUser.full_name.charAt(0) || 'U'}
                </div>
                <div className="text-left">
                  <div className="font-semibold text-slate-900 flex items-center gap-1.5">
                    <span>{currentUser.full_name}</span>
                    <span className={`text-[10px] font-bold px-1.5 py-0.2 rounded border ${getRoleBadgeStyle(currentUser.role)}`}>
                      {getRoleLabel(currentUser.role)}
                    </span>
                  </div>
                  <div className="text-[11px] text-slate-500 flex items-center gap-2">
                    <span className="flex items-center gap-1">
                      <Phone className="w-3 h-3 text-slate-400" />
                      {currentUser.phone}
                    </span>
                    {currentUser.palika_code && (
                      <span className="flex items-center gap-1">
                        <MapPin className="w-3 h-3 text-slate-400" />
                        Palika: {currentUser.palika_code}
                      </span>
                    )}
                  </div>
                </div>
              </div>

              <button
                type="button"
                onClick={logout}
                className="inline-flex items-center space-x-1.5 px-3 py-1.5 rounded-lg border border-slate-200 text-xs font-semibold text-slate-700 hover:text-red-600 hover:bg-red-50 hover:border-red-200 transition-colors"
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
        <div className="bg-slate-900 text-white text-[11px] font-medium py-1.5 px-4 sm:px-6 lg:px-8 border-t border-slate-800">
          <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <Shield className="w-3.5 h-3.5 text-blue-400 shrink-0" />
              <span>
                Active Jurisdiction:{' '}
                <strong className="text-blue-300">
                  {currentUser.role === 'admin'
                    ? 'Federal Authority (All 753 Municipalities & 6,743 Wards)'
                    : `Palika Code: ${currentUser.palika_code} (${currentUser.assigned_wards.includes('*') ? 'All Municipal Wards' : `Wards: ${currentUser.assigned_wards.join(', ')}`})`}
                </strong>
              </span>
            </div>
            <div className="text-slate-400 text-[10px]">
              Session Secured • EdDSA Bearer Token
            </div>
          </div>
        </div>
      )}
    </header>
  );
};
