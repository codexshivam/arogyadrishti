import React, { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { fetchSpatialHierarchy } from '../services/api';
import { AdministrativeHierarchy } from '../types';
import { LogOut, MapPin } from 'lucide-react';

const KNOWN_WARDS: Record<string, { no: number; name: string }> = {
  'NP-P3-D27-30608-W01': { no: 1, name: 'Naxal' },
  'NP-P3-D27-30608-W02': { no: 2, name: 'Lazimpat' },
  'NP-P3-D27-30608-W03': { no: 3, name: 'Maharajgunj' },
  'NP-P3-D27-30608-W04': { no: 4, name: 'Baluwatar' },
  'NP-P3-D27-30608-W05': { no: 5, name: 'Tangal / Hadigaun' },
  'NP-P3-D27-30608-W06': { no: 6, name: 'Boudha' },
  'NP-P3-D27-30608-W07': { no: 7, name: 'Chabahil / Mitrapark' },
  'NP-P3-D27-30608-W08': { no: 8, name: 'Pashupatinath / Gaushala' },
  'NP-P3-D27-30608-W09': { no: 9, name: 'Sinamangal / Battisputali' },
  'NP-P3-D27-30608-W10': { no: 10, name: 'Baneshwor' },
  'NP-P3-D27-30608-W11': { no: 11, name: 'Tripureshwor / Thapathali' },
  'NP-P3-D27-30608-W12': { no: 12, name: 'Teku' },
  'NP-P3-D27-30608-W13': { no: 13, name: 'Kalimati / Bafal' },
  'NP-P3-D27-30608-W14': { no: 14, name: 'Kalanki / Kuleshwor' },
  'NP-P3-D27-30608-W15': { no: 15, name: 'Swoyambhu / Dallu' },
  'NP-P3-D27-30608-W16': { no: 16, name: 'Balaju / Banasthali' },
  'NP-P3-D27-30608-W17': { no: 17, name: 'Chhetrapati' },
  'NP-P3-D27-30608-W18': { no: 18, name: 'Naradevi / Tengal' },
  'NP-P3-D27-30608-W19': { no: 19, name: 'Damaitole / Hanumandhoka' },
  'NP-P3-D27-30608-W20': { no: 20, name: 'Bhimsensthan / Maru' },
  'NP-P3-D27-30608-W21': { no: 21, name: 'Jaisidewal / Lagan' },
  'NP-P3-D27-30608-W22': { no: 22, name: 'New Road / Tebahal' },
  'NP-P3-D27-30608-W23': { no: 23, name: 'Om Bahal / Basantapur' },
  'NP-P3-D27-30608-W24': { no: 24, name: 'Makhan / Indrachowk' },
  'NP-P3-D27-30608-W25': { no: 25, name: 'Asan / Keltole' },
  'NP-P3-D27-30608-W26': { no: 26, name: 'Lainchaur / Thamel' },
  'NP-P3-D27-30608-W27': { no: 27, name: 'Mahaboudha / Bhotahiti' },
  'NP-P3-D27-30608-W28': { no: 28, name: 'Bagbazar / Putalisadak' },
  'NP-P3-D27-30608-W29': { no: 29, name: 'Dillibazar / Ghattekulo' },
  'NP-P3-D27-30608-W30': { no: 30, name: 'Maitidevi / Gyaneshwor' },
  'NP-P3-D27-30608-W31': { no: 31, name: 'Minbhawan / Shantinagar' },
  'NP-P3-D27-30608-W32': { no: 32, name: 'Koteshwor / Tinkune' },
  'NP-P3-D28-30805-W03': { no: 3, name: 'Pulchowk' },
  'NP-P3-D28-30805-W04': { no: 4, name: 'Jawalakhel' },
  'NP-P3-D35-30502-W10': { no: 10, name: 'Hospital Road' },
  'NP-P4-D40-40505-W06': { no: 6, name: 'Lakeside Baidam' },
};

export const Header: React.FC = () => {
  const { currentUser, logout } = useAuth();
  const [hierarchy, setHierarchy] = useState<AdministrativeHierarchy | null>(null);

  useEffect(() => {
    fetchSpatialHierarchy()
      .then((data) => setHierarchy(data))
      .catch((e) => console.error(e));
  }, []);

  const formatWard = (wardCode: string): string => {
    if (!wardCode || wardCode === '*') return 'All Wards';
    if (KNOWN_WARDS[wardCode]) {
      return `Ward ${KNOWN_WARDS[wardCode].no} - ${KNOWN_WARDS[wardCode].name}`;
    }
    if (hierarchy?.palikas) {
      for (const p of hierarchy.palikas) {
        const w = (p.wards || []).find((x) => x.composite_ward_id === wardCode);
        if (w) return `Ward ${w.ward_no} - ${w.locality_name}`;
      }
    }
    const match = wardCode.match(/-W(\d+)/i);
    if (match) {
      const num = parseInt(match[1], 10);
      return `Ward ${num}`;
    }
    return wardCode;
  };

  const getJurisdiction = (): string => {
    if (!currentUser) return '';
    if (currentUser.role === 'admin') {
      return 'Federal Administration (Nationwide - All Municipalities & Wards)';
    }
    const palikaObj = hierarchy?.palikas?.find((p) => p.palika_code === currentUser.palika_code);
    const palikaName = palikaObj?.palika_name || (currentUser.palika_code === '30608' ? 'Kathmandu Metropolitan City' : `Palika ${currentUser.palika_code}`);
    return palikaName;
  };

  const getAssignedWardDisplay = (): string | null => {
    if (!currentUser || currentUser.role === 'admin') return null;
    const wards = currentUser.assigned_wards || [];
    if (wards.length === 0 || wards.includes('*') || currentUser.role === 'municipality_admin') {
      return null;
    }
    return wards.map((w) => formatWard(w)).join(', ');
  };

  return (
    <header className="bg-transparent sticky top-0 z-50">
      {/* Top Bar */}
      <div className="bg-white/95 backdrop-blur-xs border-b border-slate-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3 flex items-center justify-between">
          {/* Transparent background with red text logo */}
          <div className="flex items-center">
            <span className="text-2xl font-black tracking-tight text-[#a50c1f]">
              Nidan<span className="text-[#7c0012]">IQ</span>
            </span>
          </div>

          {/* Profile chip with Name | Phone Number and Signout button */}
          {currentUser && (
            <div className="flex items-center space-x-3">
              <div className="inline-flex items-center px-3.5 py-1.5 rounded-full bg-slate-100 border border-slate-200 text-xs font-semibold text-slate-800">
                <span>{currentUser.full_name}</span>
                <span className="mx-2 text-slate-400">|</span>
                <span className="font-mono text-slate-600">{currentUser.phone}</span>
              </div>

              <button
                type="button"
                onClick={logout}
                className="inline-flex items-center space-x-1.5 px-3 py-1.5 rounded-lg border border-slate-300 text-xs font-semibold text-slate-700 hover:text-[#a50c1f] hover:border-[#a50c1f] hover:bg-red-50 transition-colors cursor-pointer"
                title="Sign Out"
              >
                <LogOut className="w-3.5 h-3.5" />
                <span>Sign Out</span>
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Red Strip with active Jurisdiction and Assigned Ward (Name + Ward No, not ward code) */}
      {currentUser && (
        <div className="bg-[#a50c1f] text-white text-xs font-medium py-2 px-4 sm:px-6 lg:px-8 shadow-xs">
          <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <MapPin className="w-3.5 h-3.5 text-[#ffdad7] shrink-0" />
              <span>
                Active Jurisdiction: <strong className="font-semibold text-white">{getJurisdiction()}</strong>
                {getAssignedWardDisplay() && (
                  <>
                    <span className="mx-2 text-[#ffb1ad]">|</span>
                    <span>Assigned Ward: <strong className="font-semibold text-white">{getAssignedWardDisplay()}</strong></span>
                  </>
                )}
              </span>
            </div>
          </div>
        </div>
      )}
    </header>
  );
};
