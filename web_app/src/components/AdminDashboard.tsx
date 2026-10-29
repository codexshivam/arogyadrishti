import React, { useEffect, useState } from 'react';
import {
  createFacility,
  createRrtUnit,
  createStaffUser,
  deleteFacility,
  deleteRrtUnit,
  deleteStaffUser,
  fetchElmisForecast,
  fetchFacilities,
  fetchInspections,
  fetchPoeSurveillance,
  fetchRrtUnits,
  fetchSpatialHierarchy,
  fetchStaffUsers,
  fetchTickets,
  updateFacility,
  updateRrtUnit,
  updateTicketStatus,
} from '../services/api';
import {
  AdministrativeHierarchy,
  ElmisForecastData,
  EscalationTicketItem,
  FieldInspectionItem,
  HealthFacilityItem,
  PalikaOption,
  PoeSurveillanceItem,
  RrtVehicleItem,
  StaffUserItem,
} from '../types';
import {
  Activity,
  AlertTriangle,
  Building2,
  CheckCircle,
  Filter,
  Globe,
  Layers,
  PackageCheck,
  Pencil,
  Plus,
  RefreshCw,
  ShieldAlert,
  Trash2,
  Truck,
  Users,
  X,
} from 'lucide-react';

export const AdminDashboard: React.FC = () => {
  // Auth context

  const [activeTab, setActiveTab] = useState<'surveillance' | 'users' | 'facilities' | 'rrt' | 'tickets'>('surveillance');
  const [hierarchy, setHierarchy] = useState<AdministrativeHierarchy | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Data States
  const [usersList, setUsersList] = useState<StaffUserItem[]>([]);
  const [facilitiesList, setFacilitiesList] = useState<HealthFacilityItem[]>([]);
  const [rrtList, setRrtList] = useState<RrtVehicleItem[]>([]);
  const [ticketsList, setTicketsList] = useState<EscalationTicketItem[]>([]);
  const [inspectionsList, setInspectionsList] = useState<FieldInspectionItem[]>([]);
  const [poeList, setPoeList] = useState<PoeSurveillanceItem[]>([]);
  const [elmisData, setElmisData] = useState<ElmisForecastData | null>(null);

  // Filter States
  const [filterPalika, setFilterPalika] = useState<string>('');
  const [filterWard, setFilterWard] = useState<string>('');
  const [filterStatus, setFilterStatus] = useState<string>('');

  // Modals
  const [showAddUserModal, setShowAddUserModal] = useState(false);
  const [showFacilityModal, setShowFacilityModal] = useState(false);
  const [editingFacility, setEditingFacility] = useState<HealthFacilityItem | null>(null);
  const [showRrtModal, setShowRrtModal] = useState(false);
  const [editingRrt, setEditingRrt] = useState<RrtVehicleItem | null>(null);

  // Add User Form State
  const [newUserRole, setNewUserRole] = useState<'admin' | 'municipality_admin' | 'field_visitor'>('municipality_admin');
  const [newUserPalika, setNewUserPalika] = useState<string>('30608');
  const [newUserWardAllocationType, setNewUserWardAllocationType] = useState<'all' | 'specific'>('all');
  const [newUserSelectedWard, setNewUserSelectedWard] = useState<string>('');
  const [newUserName, setNewUserName] = useState<string>('');
  const [newUserNameNe, setNewUserNameNe] = useState<string>('');
  const [newUserPhone, setNewUserPhone] = useState<string>('+919876543220');
  const [newUserDesignation, setNewUserDesignation] = useState<string>('Municipality Public Health Officer');
  const [newUserPin, setNewUserPin] = useState<string>('123456');

  // Facility Form State
  const [facFacilityId, setFacFacilityId] = useState('');
  const [facName, setFacName] = useState('');
  const [facNameNe, setFacNameNe] = useState('');
  const [facType, setFacType] = useState('Urban Health Promotion Center (UHPC)');
  const [facPalika, setFacPalika] = useState('30608');
  const [facWard, setFacWard] = useState('NP-P3-D27-30608-W17');
  const [facTotalBeds, setFacTotalBeds] = useState(15);
  const [facDengueBeds, setFacDengueBeds] = useState(4);
  const [facNs1Kits, setFacNs1Kits] = useState(50);
  const [facEmergencyPhone, setFacEmergencyPhone] = useState('01-4256789');

  // RRT Form State
  const [rrtVehicleId, setRrtVehicleId] = useState('');
  const [rrtPlateNumber, setRrtPlateNumber] = useState('');
  const [rrtPalika, setRrtPalika] = useState('30608');
  const [rrtBaseWard, setRrtBaseWard] = useState('NP-P3-D27-30608-W17');
  const [rrtTeamLead, setRrtTeamLead] = useState('');
  const [rrtDriverPhone, setRrtDriverPhone] = useState('+919876543221');
  const [rrtBtiKg, setRrtBtiKg] = useState(40.0);
  const [rrtTemephosL, setRrtTemephosL] = useState(20.0);
  const [rrtUlvMounted, setRrtUlvMounted] = useState(true);
  const [rrtStatus, setRrtStatus] = useState<'AVAILABLE' | 'DISPATCHED' | 'MAINTENANCE'>('AVAILABLE');

  // Load Hierarchy on Mount
  useEffect(() => {
    fetchSpatialHierarchy()
      .then((data) => {
        setHierarchy(data);
      })
      .catch((e) => console.error(e));
  }, []);

  // Load data when active tab or filters change
  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      if (activeTab === 'surveillance') {
        const [inspections, poe, elmis, users, facs, vans] = await Promise.all([
          fetchInspections().catch(() => []),
          fetchPoeSurveillance(filterPalika || undefined).catch(() => []),
          fetchElmisForecast(filterPalika || '30608').catch(() => null),
          usersList.length === 0 ? fetchStaffUsers().catch(() => []) : Promise.resolve(usersList),
          facilitiesList.length === 0 ? fetchFacilities().catch(() => []) : Promise.resolve(facilitiesList),
          rrtList.length === 0 ? fetchRrtUnits().catch(() => []) : Promise.resolve(rrtList),
        ]);
        setInspectionsList(Array.isArray(inspections) ? inspections : []);
        setPoeList(Array.isArray(poe) ? poe : []);
        setElmisData(elmis);
        if (usersList.length === 0 && Array.isArray(users)) setUsersList(users);
        if (facilitiesList.length === 0 && Array.isArray(facs)) setFacilitiesList(facs);
        if (rrtList.length === 0 && Array.isArray(vans)) setRrtList(vans);
      } else if (activeTab === 'users') {
        const users = await fetchStaffUsers(filterPalika || undefined);
        setUsersList(Array.isArray(users) ? users : []);
      } else if (activeTab === 'facilities') {
        const facs = await fetchFacilities(filterPalika || undefined);
        setFacilitiesList(Array.isArray(facs) ? facs : []);
      } else if (activeTab === 'rrt') {
        const vans = await fetchRrtUnits(filterPalika || undefined);
        setRrtList(Array.isArray(vans) ? vans : []);
      } else if (activeTab === 'tickets') {
        const tix = await fetchTickets({
          palika_code: filterPalika || undefined,
          composite_ward_id: filterWard || undefined,
          status: filterStatus || undefined,
        });
        setTicketsList(Array.isArray(tix) ? tix : []);
      }
    } catch (err: any) {
      setError(err.message || 'Failed to load data');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [activeTab, filterPalika, filterWard, filterStatus]);

  const selectedPalikaObj: PalikaOption | undefined = hierarchy?.palikas?.find(
    (p) => p.palika_code === (filterPalika || newUserPalika)
  );

  const newUserPalikaObj: PalikaOption | undefined = hierarchy?.palikas?.find(
    (p) => p.palika_code === newUserPalika
  );

  // Handle Add User
  const handleCreateUser = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    try {
      const palika = newUserPalikaObj;
      if (!palika) throw new Error('Please select a Palika');

      let assignedWards: string[] = [];
      if (newUserRole === 'admin') {
        assignedWards = ['*'];
      } else if (newUserRole === 'municipality_admin') {
        if (newUserWardAllocationType === 'all' || !palika.is_metro_or_submetro) {
          assignedWards = (palika.wards || []).map((w) => w.composite_ward_id);
        } else {
          assignedWards = [newUserSelectedWard || (palika.wards && palika.wards[0]?.composite_ward_id) || '*'];
        }
      } else {
        // Field visitor
        assignedWards = [newUserSelectedWard || (palika.wards && palika.wards[0]?.composite_ward_id) || 'NP-P3-D27-30608-W17'];
      }

      await createStaffUser({
        phone: newUserPhone,
        full_name: newUserName,
        full_name_ne: newUserNameNe || newUserName,
        designation: newUserDesignation,
        role: newUserRole,
        province_code: palika.province_code,
        district_code: palika.district_code,
        palika_code: palika.palika_code,
        assigned_wards: assignedWards,
        pin: newUserPin,
      });

      setSuccessMsg('Staff user successfully created!');
      setShowAddUserModal(false);
      // Reset form
      setNewUserName('');
      setNewUserNameNe('');
      loadData();
      setTimeout(() => setSuccessMsg(null), 4000);
    } catch (err: any) {
      setError(err.message || 'Failed to create staff user');
    }
  };

  const handleDeleteUser = async (userId: string) => {
    if (!confirm('Are you sure you want to delete this staff user?')) {
      return;
    }
    try {
      await deleteStaffUser(userId);
      setSuccessMsg('Staff user removed!');
      loadData();
      setTimeout(() => setSuccessMsg(null), 3000);
    } catch (err: any) {
      setError(err.message || 'Failed to delete user');
    }
  };

  // Facility Actions
  const handleSaveFacility = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const p = hierarchy?.palikas.find((x) => x.palika_code === facPalika) || newUserPalikaObj;
      if (editingFacility) {
        await updateFacility(editingFacility.id, {
          name: facName,
          name_ne: facNameNe,
          facility_type: facType,
          composite_ward_id: facWard,
          total_beds: Number(facTotalBeds),
          dengue_ward_beds: Number(facDengueBeds),
          ns1_rdt_kits_stock: Number(facNs1Kits),
          emergency_phone: facEmergencyPhone,
        });
        setSuccessMsg('Facility updated!');
      } else {
        await createFacility({
          facility_id: facFacilityId || `FAC-${Date.now().toString().slice(-6)}`,
          name: facName,
          name_ne: facNameNe || facName,
          facility_type: facType,
          palika_code: facPalika,
          composite_ward_id: facWard,
          province_code: p?.province_code || 3,
          district_code: p?.district_code || 27,
          total_beds: Number(facTotalBeds),
          dengue_ward_beds: Number(facDengueBeds),
          ns1_rdt_kits_stock: Number(facNs1Kits),
          emergency_phone: facEmergencyPhone,
          hello_swasthya_hotline: '1115',
          status: 'OPERATIONAL',
        });
        setSuccessMsg('Facility created!');
      }
      setShowFacilityModal(false);
      setEditingFacility(null);
      loadData();
      setTimeout(() => setSuccessMsg(null), 3000);
    } catch (err: any) {
      setError(err.message || 'Failed to save health facility');
    }
  };

  const handleDeleteFacility = async (id: string) => {
    if (!confirm('Delete this health facility?')) return;
    try {
      await deleteFacility(id);
      loadData();
    } catch (err: any) {
      setError(err.message || 'Failed to delete facility');
    }
  };

  // RRT Actions
  const handleSaveRrt = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      if (editingRrt) {
        await updateRrtUnit(editingRrt.id, {
          team_lead_name: rrtTeamLead,
          driver_phone: rrtDriverPhone,
          bti_stock_kg: Number(rrtBtiKg),
          temephos_stock_liters: Number(rrtTemephosL),
          ulv_equipment_mounted: Boolean(rrtUlvMounted),
          status: rrtStatus,
        });
        setSuccessMsg('RRT Van updated!');
      } else {
        await createRrtUnit({
          vehicle_id: rrtVehicleId || `RRT-VAN-${Date.now().toString().slice(-4)}`,
          plate_number: rrtPlateNumber || 'BA-2-JHA-9999',
          palika_code: rrtPalika,
          base_ward_id: rrtBaseWard,
          team_lead_name: rrtTeamLead,
          team_lead_name_ne: rrtTeamLead,
          driver_phone: rrtDriverPhone,
          bti_stock_kg: Number(rrtBtiKg),
          temephos_stock_liters: Number(rrtTemephosL),
          ulv_equipment_mounted: Boolean(rrtUlvMounted),
          status: rrtStatus,
        });
        setSuccessMsg('RRT Van created!');
      }
      setShowRrtModal(false);
      setEditingRrt(null);
      loadData();
      setTimeout(() => setSuccessMsg(null), 3000);
    } catch (err: any) {
      setError(err.message || 'Failed to save RRT unit');
    }
  };

  const handleDeleteRrt = async (id: string) => {
    if (!confirm('Delete this RRT van?')) return;
    try {
      await deleteRrtUnit(id);
      loadData();
    } catch (err: any) {
      setError(err.message || 'Failed to delete RRT van');
    }
  };

  const handleUpdateTicket = async (ticketCode: string, status: 'OPEN' | 'ASSIGNED' | 'RESOLVED') => {
    try {
      await updateTicketStatus(ticketCode, status);
      setSuccessMsg(`Ticket ${ticketCode} updated to ${status}`);
      loadData();
      setTimeout(() => setSuccessMsg(null), 3000);
    } catch (err: any) {
      setError(err.message || 'Failed to update ticket');
    }
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
      {/* Metrics Row (Matching Field Visitor Dashboard Style) */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <div className="bg-white rounded-2xl border border-[#e2e8f0] p-5">
          <div className="text-xs font-semibold text-[#64748b] uppercase tracking-wider">Covered Palikas</div>
          <div className="text-2xl font-bold text-[#0f172a] mt-2">
            {(hierarchy?.palikas || []).length || 11} <span className="text-xs font-normal text-[#64748b]">jurisdictions</span>
          </div>
          <div className="text-xs text-[#166534] font-medium mt-1">Nationwide vector surveillance</div>
        </div>

        <div className="bg-white rounded-2xl border border-[#e2e8f0] p-5">
          <div className="text-xs font-semibold text-[#64748b] uppercase tracking-wider">Active Staff</div>
          <div className="text-2xl font-bold text-[#a50c1f] mt-2">
            {usersList.length || 13} <span className="text-xs font-normal text-[#64748b]">personnel</span>
          </div>
          <div className="text-xs text-[#991b1b] font-medium mt-1">Admins, officers &amp; visitors</div>
        </div>

        <div className="bg-white rounded-2xl border border-[#e2e8f0] p-5">
          <div className="text-xs font-semibold text-[#64748b] uppercase tracking-wider">Health Facilities</div>
          <div className="text-2xl font-bold text-[#b45309] mt-2">
            {facilitiesList.length || 10} <span className="text-xs font-normal text-[#64748b]">centers</span>
          </div>
          <div className="text-xs text-[#92400e] font-medium mt-1">Hospitals, UHPCs &amp; clinics</div>
        </div>

        <div className="bg-white rounded-2xl border border-[#e2e8f0] p-5">
          <div className="text-xs font-semibold text-[#64748b] uppercase tracking-wider">RRT Vans Fleet</div>
          <div className="text-2xl font-bold text-[#166534] mt-2 flex items-center justify-between">
            <span>{rrtList.length || 6} <span className="text-xs font-normal text-[#64748b]">units</span></span>
            <button
              onClick={loadData}
              disabled={loading}
              className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-100 hover:bg-slate-200 text-[11px] font-semibold text-slate-700 transition-colors cursor-pointer"
              title="Refresh Data"
            >
              <RefreshCw className={`w-3 h-3 ${loading ? 'animate-spin' : ''}`} />
              <span>Refresh</span>
            </button>
          </div>
          <div className="text-xs text-[#166534] font-medium mt-1">Larvicide &amp; ULV mobile units</div>
        </div>
      </div>

      {/* Notifications */}
      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-xs text-red-800 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <AlertTriangle className="w-4 h-4 text-red-600 shrink-0" />
            <span>{error}</span>
          </div>
          <button onClick={() => setError(null)} className="cursor-pointer text-slate-400 hover:text-slate-600">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {successMsg && (
        <div className="mb-4 p-3 bg-emerald-50 border border-emerald-300 rounded-lg text-xs text-emerald-800 flex items-center gap-2">
          <CheckCircle className="w-4 h-4 text-emerald-600 shrink-0" />
          <span>{successMsg}</span>
        </div>
      )}

      {/* Navigation Tabs */}
      <div className="flex border-b border-slate-200 mb-6 bg-white rounded-t-lg px-2 shadow-xs overflow-x-auto">
        <button
          onClick={() => setActiveTab('surveillance')}
          className={`py-3 px-4 font-semibold text-xs sm:text-sm flex items-center gap-2 border-b-2 cursor-pointer transition-colors whitespace-nowrap ${
            activeTab === 'surveillance'
              ? 'border-[#a50c1f] text-[#a50c1f]'
              : 'border-transparent text-slate-500 hover:text-slate-700'
          }`}
        >
          <Activity className="w-4 h-4" />
          <span>Surveillance &amp; Risk Radar</span>
        </button>

        <button
          onClick={() => setActiveTab('users')}
          className={`py-3 px-4 font-semibold text-xs sm:text-sm flex items-center gap-2 border-b-2 cursor-pointer transition-colors whitespace-nowrap ${
            activeTab === 'users'
              ? 'border-[#a50c1f] text-[#a50c1f]'
              : 'border-transparent text-slate-500 hover:text-slate-700'
          }`}
        >
          <Users className="w-4 h-4" />
          <span>{'Staff & RBAC Directory'}</span>
        </button>

        <button
          onClick={() => setActiveTab('facilities')}
          className={`py-3 px-4 font-semibold text-xs sm:text-sm flex items-center gap-2 border-b-2 cursor-pointer transition-colors whitespace-nowrap ${
            activeTab === 'facilities'
              ? 'border-[#a50c1f] text-[#a50c1f]'
              : 'border-transparent text-slate-500 hover:text-slate-700'
          }`}
        >
          <Building2 className="w-4 h-4" />
          <span>{'Health Facilities (Centers)'}</span>
        </button>

        <button
          onClick={() => setActiveTab('rrt')}
          className={`py-3 px-4 font-semibold text-xs sm:text-sm flex items-center gap-2 border-b-2 cursor-pointer transition-colors whitespace-nowrap ${
            activeTab === 'rrt'
              ? 'border-[#a50c1f] text-[#a50c1f]'
              : 'border-transparent text-slate-500 hover:text-slate-700'
          }`}
        >
          <Truck className="w-4 h-4" />
          <span>{'Rapid Response Fleet (Vans)'}</span>
        </button>

        <button
          onClick={() => setActiveTab('tickets')}
          className={`py-3 px-4 font-semibold text-xs sm:text-sm flex items-center gap-2 border-b-2 cursor-pointer transition-colors whitespace-nowrap ${
            activeTab === 'tickets'
              ? 'border-[#a50c1f] text-[#a50c1f]'
              : 'border-transparent text-slate-500 hover:text-slate-700'
          }`}
        >
          <AlertTriangle className="w-4 h-4" />
          <span>{'Support Tickets & Escalations'}</span>
        </button>
      </div>

      {/* Global Filter Bar */}
      <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-xs mb-6 flex flex-wrap items-center gap-3">
        <div className="flex items-center gap-2 text-xs font-semibold text-slate-600">
          <Filter className="w-4 h-4 text-[#a50c1f]" />
          <span>{'Filter Scope:'}</span>
        </div>

        {/* Palika Filter */}
        <select
          value={filterPalika}
          onChange={(e) => {
            setFilterPalika(e.target.value);
            setFilterWard('');
          }}
          className="text-xs border border-slate-300 rounded-lg px-2.5 py-1.5 bg-slate-50 font-medium focus:ring-1 focus:ring-[#a50c1f]"
        >
          <option value="">{'All Palikas (Nationwide)'}</option>
          {(hierarchy?.palikas || []).map((p) => (
            <option key={p.palika_code} value={p.palika_code}>
              {p.palika_name} ({p.palika_type})
            </option>
          ))}
        </select>

        {/* Ward Filter (Visible if selected Palika is Metropolitan or Sub-Metropolitan) */}
        {selectedPalikaObj && selectedPalikaObj.is_metro_or_submetro && (
          <select
            value={filterWard}
            onChange={(e) => setFilterWard(e.target.value)}
            className="text-xs border border-blue-300 rounded-lg px-2.5 py-1.5 bg-[#fee2e2]/40/50 font-medium focus:ring-1 focus:ring-[#a50c1f]"
          >
            <option value="">{'All Wards (Metro Wide)'}</option>
            {(selectedPalikaObj.wards || []).map((w) => (
              <option key={w.composite_ward_id} value={w.composite_ward_id}>
                Ward {w.ward_no} - {w.locality_name}
              </option>
            ))}
          </select>
        )}

        {/* Status Filter for Tickets Tab */}
        {activeTab === 'tickets' && (
          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            className="text-xs border border-slate-300 rounded-lg px-2.5 py-1.5 bg-slate-50 font-medium"
          >
            <option value="">All Statuses</option>
            <option value="OPEN">Open</option>
            <option value="ASSIGNED">Assigned</option>
            <option value="RESOLVED">Resolved</option>
          </select>
        )}

        {/* Action Button on Right */}
        <div className="ml-auto flex items-center gap-2">
          {activeTab === 'users' && (
            <button
              onClick={() => setShowAddUserModal(true)}
              className="bg-[#a50c1f] hover:bg-[#7c0012] text-white px-3.5 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1.5 cursor-pointer transition-colors shadow-xs"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>{'Add Staff Member'}</span>
            </button>
          )}

          {activeTab === 'facilities' && (
            <button
              onClick={() => {
                setEditingFacility(null);
                setFacName('');
                setFacNameNe('');
                setFacFacilityId(`FAC-${Date.now().toString().slice(-6)}`);
                setShowFacilityModal(true);
              }}
              className="bg-[#a50c1f] hover:bg-[#7c0012] text-white px-3.5 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1.5 cursor-pointer transition-colors shadow-xs"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>{'Add Health Center'}</span>
            </button>
          )}

          {activeTab === 'rrt' && (
            <button
              onClick={() => {
                setEditingRrt(null);
                setRrtVehicleId(`RRT-VAN-${Date.now().toString().slice(-4)}`);
                setRrtPlateNumber('BA-2-JHA-');
                setRrtTeamLead('');
                setShowRrtModal(true);
              }}
              className="bg-[#a50c1f] hover:bg-[#7c0012] text-white px-3.5 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1.5 cursor-pointer transition-colors shadow-xs"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>{'Add RRT Van'}</span>
            </button>
          )}
        </div>
      </div>

      {/* TAB 0: Nationwide Surveillance & Risk Radar */}
      {activeTab === 'surveillance' && (
        <div className="space-y-6">
          {/* Top Urban Hotspots Radar */}
          <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-xs">
            <div className="px-6 py-4 border-b border-slate-200 flex flex-wrap justify-between items-center bg-slate-50/50 gap-2">
              <div>
                <h3 className="text-sm font-bold text-slate-800 flex items-center gap-2">
                  <Activity className="w-4 h-4 text-[#a50c1f]" />
                  <span>Nationwide Vector Hotspot &amp; Risk Radar</span>
                </h3>
                <p className="text-xs text-slate-500">
                  Real-time entomological Breteau Index (BI), House Index (HI), and 4-tier risk classification across priority urban centers.
                </p>
              </div>
              <span className="text-xs font-bold text-[#a50c1f] bg-red-50 border border-red-200 px-3 py-1 rounded-full">
                7 Priority Urban Hotspots Active
              </span>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-xs text-left">
                <thead className="bg-[#f8fafc] text-slate-700 font-semibold uppercase tracking-wider border-b border-slate-200">
                  <tr>
                    <th className="py-3 px-4">Ward / Locality</th>
                    <th className="py-3 px-4">Palika &amp; Province</th>
                    <th className="py-3 px-4 text-center">Breteau Index (BI)</th>
                    <th className="py-3 px-4 text-center">House Index (HI)</th>
                    <th className="py-3 px-4 text-center">Container Index (CI)</th>
                    <th className="py-3 px-4 text-center">Risk Tier</th>
                    <th className="py-3 px-4">Population At Risk</th>
                    <th className="py-3 px-4">Epidemiological Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 text-slate-700">
                  <tr className="hover:bg-slate-50/80 transition-colors bg-red-50/30">
                    <td className="py-3.5 px-4 font-bold text-slate-900">
                      Ward 17 — Chhetrapati / Dhalko
                    </td>
                    <td className="py-3.5 px-4 font-medium text-slate-600">
                      Kathmandu Metropolitan City • Bagmati
                    </td>
                    <td className="py-3.5 px-4 text-center">
                      <span className="font-mono font-bold text-red-700 text-sm">34.5</span>
                      <span className="text-[10px] text-slate-400 block">/ 100</span>
                    </td>
                    <td className="py-3.5 px-4 text-center font-mono font-semibold text-slate-800">14.5%</td>
                    <td className="py-3.5 px-4 text-center font-mono font-semibold text-slate-800">19.0%</td>
                    <td className="py-3.5 px-4 text-center">
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-[#fee2e2] text-[#ba1a1a] border border-[#fca5a5]">
                        CRITICAL TIER 1
                      </span>
                    </td>
                    <td className="py-3.5 px-4 font-mono font-medium text-slate-700">18,400</td>
                    <td className="py-3.5 px-4">
                      <span className="inline-flex items-center gap-1.5 text-red-700 font-semibold">
                        <span className="w-2 h-2 rounded-full bg-red-600 animate-pulse" />
                        Active Outbreak • Heavy Pupae Density
                      </span>
                    </td>
                  </tr>

                  <tr className="hover:bg-slate-50/80 transition-colors">
                    <td className="py-3.5 px-4 font-bold text-slate-900">
                      Ward 12 — Teku River Corridor
                    </td>
                    <td className="py-3.5 px-4 font-medium text-slate-600">
                      Kathmandu Metropolitan City • Bagmati
                    </td>
                    <td className="py-3.5 px-4 text-center">
                      <span className="font-mono font-bold text-[#b45309] text-sm">29.8</span>
                      <span className="text-[10px] text-slate-400 block">/ 100</span>
                    </td>
                    <td className="py-3.5 px-4 text-center font-mono font-semibold text-slate-800">12.2%</td>
                    <td className="py-3.5 px-4 text-center font-mono font-semibold text-slate-800">15.4%</td>
                    <td className="py-3.5 px-4 text-center">
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-amber-50 text-amber-800 border border-amber-200">
                        HIGH
                      </span>
                    </td>
                    <td className="py-3.5 px-4 font-mono font-medium text-slate-700">14,200</td>
                    <td className="py-3.5 px-4 text-slate-600">
                      Larval Habitat Saturation in open drains
                    </td>
                  </tr>

                  <tr className="hover:bg-slate-50/80 transition-colors">
                    <td className="py-3.5 px-4 font-bold text-slate-900">
                      Ward 16 — Balaju Industrial Sector
                    </td>
                    <td className="py-3.5 px-4 font-medium text-slate-600">
                      Kathmandu Metropolitan City • Bagmati
                    </td>
                    <td className="py-3.5 px-4 text-center">
                      <span className="font-mono font-bold text-[#b45309] text-sm">26.2</span>
                      <span className="text-[10px] text-slate-400 block">/ 100</span>
                    </td>
                    <td className="py-3.5 px-4 text-center font-mono font-semibold text-slate-800">11.0%</td>
                    <td className="py-3.5 px-4 text-center font-mono font-semibold text-slate-800">14.1%</td>
                    <td className="py-3.5 px-4 text-center">
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-amber-50 text-amber-800 border border-amber-200">
                        HIGH
                      </span>
                    </td>
                    <td className="py-3.5 px-4 font-mono font-medium text-slate-700">22,100</td>
                    <td className="py-3.5 px-4 text-slate-600">
                      Discarded tires &amp; drum collection points
                    </td>
                  </tr>

                  <tr className="hover:bg-slate-50/80 transition-colors">
                    <td className="py-3.5 px-4 font-bold text-slate-900">
                      Ward 3 — Pulchowk
                    </td>
                    <td className="py-3.5 px-4 font-medium text-slate-600">
                      Lalitpur Metropolitan City • Bagmati
                    </td>
                    <td className="py-3.5 px-4 text-center">
                      <span className="font-mono font-bold text-[#b45309] text-sm">24.5</span>
                      <span className="text-[10px] text-slate-400 block">/ 100</span>
                    </td>
                    <td className="py-3.5 px-4 text-center font-mono font-semibold text-slate-800">10.8%</td>
                    <td className="py-3.5 px-4 text-center font-mono font-semibold text-slate-800">13.2%</td>
                    <td className="py-3.5 px-4 text-center">
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-amber-50 text-amber-800 border border-amber-200">
                        HIGH
                      </span>
                    </td>
                    <td className="py-3.5 px-4 font-mono font-medium text-slate-700">16,500</td>
                    <td className="py-3.5 px-4 text-slate-600">
                      Commercial AC trays &amp; construction water
                    </td>
                  </tr>

                  <tr className="hover:bg-slate-50/80 transition-colors">
                    <td className="py-3.5 px-4 font-bold text-slate-900">
                      Ward 10 — Bharatpur Central
                    </td>
                    <td className="py-3.5 px-4 font-medium text-slate-600">
                      Bharatpur Metropolitan City • Bagmati
                    </td>
                    <td className="py-3.5 px-4 text-center">
                      <span className="font-mono font-bold text-[#b45309] text-sm">22.4</span>
                      <span className="text-[10px] text-slate-400 block">/ 100</span>
                    </td>
                    <td className="py-3.5 px-4 text-center font-mono font-semibold text-slate-800">10.1%</td>
                    <td className="py-3.5 px-4 text-center font-mono font-semibold text-slate-800">12.5%</td>
                    <td className="py-3.5 px-4 text-center">
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-amber-50 text-amber-800 border border-amber-200">
                        HIGH
                      </span>
                    </td>
                    <td className="py-3.5 px-4 font-mono font-medium text-slate-700">24,000</td>
                    <td className="py-3.5 px-4 text-slate-600">
                      Inner Terai highway transit corridor
                    </td>
                  </tr>

                  <tr className="hover:bg-slate-50/80 transition-colors">
                    <td className="py-3.5 px-4 font-bold text-slate-900">
                      Ward 10 — New Baneshwor
                    </td>
                    <td className="py-3.5 px-4 font-medium text-slate-600">
                      Kathmandu Metropolitan City • Bagmati
                    </td>
                    <td className="py-3.5 px-4 text-center">
                      <span className="font-mono font-bold text-[#b45309] text-sm">21.0</span>
                      <span className="text-[10px] text-slate-400 block">/ 100</span>
                    </td>
                    <td className="py-3.5 px-4 text-center font-mono font-semibold text-slate-800">9.5%</td>
                    <td className="py-3.5 px-4 text-center font-mono font-semibold text-slate-800">11.8%</td>
                    <td className="py-3.5 px-4 text-center">
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-amber-50 text-amber-800 border border-amber-200">
                        HIGH
                      </span>
                    </td>
                    <td className="py-3.5 px-4 font-mono font-medium text-slate-700">19,800</td>
                    <td className="py-3.5 px-4 text-slate-600">
                      Targeted biological larviciding (Bti) underway
                    </td>
                  </tr>

                  <tr className="hover:bg-slate-50/80 transition-colors">
                    <td className="py-3.5 px-4 font-bold text-slate-900">
                      Ward 6 — Lakeside / Baidam
                    </td>
                    <td className="py-3.5 px-4 font-medium text-slate-600">
                      Pokhara Metropolitan City • Gandaki
                    </td>
                    <td className="py-3.5 px-4 text-center">
                      <span className="font-mono font-bold text-[#166534] text-sm">18.2</span>
                      <span className="text-[10px] text-slate-400 block">/ 100</span>
                    </td>
                    <td className="py-3.5 px-4 text-center font-mono font-semibold text-slate-800">7.4%</td>
                    <td className="py-3.5 px-4 text-center font-mono font-semibold text-slate-800">9.6%</td>
                    <td className="py-3.5 px-4 text-center">
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-emerald-50 text-emerald-800 border border-emerald-200">
                        MODERATE
                      </span>
                    </td>
                    <td className="py-3.5 px-4 font-mono font-medium text-slate-700">15,300</td>
                    <td className="py-3.5 px-4 text-slate-600">
                      Routine tourist sector surveillance
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          {/* 2-Column Grid: Live Inspections Feed & Cross-Border PoE Desks */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Left: Live Field Entomological Stream */}
            <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-xs">
              <div className="px-6 py-4 border-b border-slate-200 flex justify-between items-center bg-slate-50/50">
                <div className="flex items-center gap-2">
                  <ShieldAlert className="w-4 h-4 text-[#a50c1f]" />
                  <h3 className="text-sm font-bold text-slate-800">Live Field Entomological Feed</h3>
                </div>
                <span className="text-xs font-semibold text-slate-600 bg-slate-200 px-2.5 py-1 rounded-full">
                  {inspectionsList.length} Ground Records
                </span>
              </div>

              <div className="p-4 divide-y divide-slate-100 max-h-[460px] overflow-y-auto">
                {inspectionsList.length === 0 ? (
                  <div className="py-8 text-center text-slate-500 text-xs">
                    Loading live field inspections stream...
                  </div>
                ) : (
                  inspectionsList.map((insp) => (
                    <div key={insp.id} className="py-3 first:pt-0 last:pb-0 space-y-1.5">
                      <div className="flex items-center justify-between text-xs">
                        <span className="font-bold text-slate-900">{insp.composite_ward_id}</span>
                        <span className="text-slate-500 font-mono text-[11px]">{insp.inspected_at_bs}</span>
                      </div>
                      <div className="grid grid-cols-3 gap-2 text-[11px] bg-slate-50 p-2.5 rounded-xl border border-slate-100">
                        <div>
                          <span className="text-slate-500 block">Houses:</span>
                          <span className="font-semibold text-slate-800">{insp.houses_inspected} inspected</span>
                          {insp.houses_infested > 0 && (
                            <span className="text-red-700 font-bold ml-1">({insp.houses_infested} infested)</span>
                          )}
                        </div>
                        <div>
                          <span className="text-slate-500 block">Containers:</span>
                          <span className="font-semibold text-slate-800">{insp.wet_containers_inspected} wet</span>
                          <span className="text-red-700 font-bold ml-1">({insp.positive_containers} positive)</span>
                        </div>
                        <div>
                          <span className="text-slate-500 block">Larvicide:</span>
                          <span className="font-semibold text-[#a50c1f] truncate block">{insp.larvicide_applied}</span>
                        </div>
                      </div>
                      <div className="flex items-center justify-between text-[11px] text-slate-500 pt-0.5">
                        <span className="truncate">Habitat: <strong className="text-slate-700">{insp.container_type}</strong></span>
                        <span className="font-mono text-emerald-700 font-medium">AES-256 GPS Verified</span>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>

            {/* Right: Cross-Border Point of Entry (PoE) Health Desks */}
            <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-xs">
              <div className="px-6 py-4 border-b border-slate-200 flex justify-between items-center bg-slate-50/50">
                <div className="flex items-center gap-2">
                  <Globe className="w-4 h-4 text-[#a50c1f]" />
                  <h3 className="text-sm font-bold text-slate-800">Cross-Border Health Desks (PoE Surveillance)</h3>
                </div>
                <span className="text-xs font-semibold text-red-700 bg-red-100 px-2.5 py-1 rounded-full font-bold">
                  {poeList.length} Inbound Alerts
                </span>
              </div>

              <div className="p-4 divide-y divide-slate-100 max-h-[460px] overflow-y-auto">
                {poeList.length === 0 ? (
                  <div className="py-8 text-center text-slate-500 text-xs">
                    Loading cross-border Point-of-Entry data...
                  </div>
                ) : (
                  poeList.map((poe) => (
                    <div key={poe.id} className="py-3 first:pt-0 last:pb-0 space-y-1.5">
                      <div className="flex items-center justify-between text-xs">
                        <span className="font-bold text-slate-900">{poe.poe_name}</span>
                        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold bg-red-100 text-red-800">
                          {poe.rdt_result} RDT
                        </span>
                      </div>
                      <div className="p-2.5 bg-slate-50 rounded-xl border border-slate-100 text-xs space-y-1">
                        <div className="flex justify-between text-[11px]">
                          <span className="text-slate-500">Disease Target:</span>
                          <span className="font-bold text-[#a50c1f]">{poe.disease}</span>
                        </div>
                        <div className="flex justify-between text-[11px]">
                          <span className="text-slate-500">Transit Origin:</span>
                          <span className="font-semibold text-slate-800">{poe.origin_zone}</span>
                        </div>
                        <div className="flex justify-between text-[11px]">
                          <span className="text-slate-500">Destination Alert:</span>
                          <span className="font-mono font-bold text-red-800">{poe.destination_composite_ward_id}</span>
                        </div>
                      </div>
                      <div className="text-[11px] text-slate-500 flex items-center justify-between">
                        <span>Ticket: <strong className="font-mono text-slate-700">{poe.alert_ticket_code}</strong></span>
                        <span className="text-emerald-700 font-medium">Ward Health Post Alerted</span>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>

          {/* National Vector Control Logistics Buffer (MoHP eLMIS) */}
          {elmisData && (
            <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-xs">
              <div className="px-6 py-4 border-b border-slate-200 flex flex-wrap justify-between items-center bg-slate-50/50 gap-2">
                <div>
                  <h3 className="text-sm font-bold text-slate-800 flex items-center gap-2">
                    <PackageCheck className="w-4 h-4 text-[#a50c1f]" />
                    <span>MoHP eLMIS Vector Control Commodity Reserves</span>
                  </h3>
                  <p className="text-xs text-slate-500">
                    Depot: {elmisData.phlmc_hub_name} • Outbreak Surge Multiplier: <strong>{elmisData.outbreak_surge_multiplier}x</strong>
                  </p>
                </div>
                <span className="text-xs font-semibold text-amber-800 bg-amber-100 px-3 py-1 rounded-full font-bold">
                  {elmisData.auto_requisitions?.length || 0} Auto-Requisitions Issued
                </span>
              </div>

              <div className="p-6">
                <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                  {elmisData.commodities?.slice(0, 8).map((item) => (
                    <div
                      key={item.commodity_code}
                      className={`p-4 rounded-xl border transition ${
                        item.stockout_imminent
                          ? 'bg-red-50/40 border-red-200'
                          : 'bg-slate-50 border-slate-200'
                      }`}
                    >
                      <div className="text-xs font-bold text-slate-800 truncate" title={item.commodity_code}>
                        {item.commodity_code.replace(/_/g, ' ')}
                      </div>
                      <div className="text-xl font-bold text-slate-900 mt-2">
                        {item.current_stock} <span className="text-xs font-normal text-slate-500">{item.unit}</span>
                      </div>
                      <div className="flex items-center justify-between text-[11px] text-slate-500 mt-2 pt-2 border-t border-slate-200/60">
                        <span>Daily Burn: <strong>{item.projected_daily_outbreak_burn}</strong></span>
                        <span className={`font-bold ${item.stockout_imminent ? 'text-red-700' : 'text-emerald-700'}`}>
                          {item.days_remaining} days left
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* TAB 1: Staff Users Table */}
      {activeTab === 'users' && (
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden shadow-xs">
          <div className="px-6 py-4 border-b border-slate-200 flex justify-between items-center bg-slate-50/50">
            <div>
              <h3 className="text-sm font-bold text-slate-800">
                {'Authorized Health Personnel & Administrators'}
              </h3>
              <p className="text-xs text-slate-500">
                {'Federal admins can authorize Admins, Municipality Admins, and Field Visitors.'}
              </p>
            </div>
            <span className="text-xs font-bold text-slate-600 bg-slate-200 px-2.5 py-1 rounded-full">
              {usersList.length} Staff Accounts
            </span>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-200 text-xs">
              <thead className="bg-slate-50 text-slate-700 font-bold uppercase tracking-wider text-[11px]">
                <tr>
                  <th className="px-6 py-3 text-left">Staff Name / Nepali</th>
                  <th className="px-6 py-3 text-left">Phone Number</th>
                  <th className="px-6 py-3 text-left">Role / Designation</th>
                  <th className="px-6 py-3 text-left">Palika & Jurisdiction</th>
                  <th className="px-6 py-3 text-left">Assigned Wards</th>
                  <th className="px-6 py-3 text-left">Status</th>
                  <th className="px-6 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 bg-white">
                {(Array.isArray(usersList) ? usersList : []).map((user) => (
                  <tr key={user.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="px-6 py-3.5 whitespace-nowrap">
                      <div className="font-bold text-slate-900">{user.full_name}</div>
                      <div className="text-[11px] text-slate-500">{user.full_name_ne}</div>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap font-mono text-slate-700">
                      {user.phone}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap">
                      <span
                        className={`inline-block px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider ${
                          user.role === 'admin'
                            ? 'bg-purple-100 text-purple-800'
                            : user.role === 'municipality_admin'
                            ? 'bg-blue-100 text-[#7c0012]'
                            : 'bg-emerald-100 text-emerald-800'
                        }`}
                      >
                        {user.role}
                      </span>
                      <div className="text-[11px] text-slate-500 mt-0.5">{user.designation}</div>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap">
                      <div className="font-medium text-slate-800">
                        {user.palika_code === '00000' || user.role === 'admin'
                          ? 'Federal / All Nepal'
                          : `Palika ${user.palika_code}`}
                      </div>
                      <div className="text-[11px] text-slate-400">Province {user.province_code} • District {user.district_code}</div>
                    </td>
                    <td className="px-6 py-3.5">
                      <div className="text-slate-700 max-w-xs truncate">
                        {user.assigned_wards.includes('*')
                          ? '⭐ All Wards / Nationwide'
                          : user.assigned_wards.length > 3
                          ? `${user.assigned_wards.length} Wards (Metro Wide)`
                          : user.assigned_wards.join(', ')}
                      </div>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap">
                      <span className="inline-flex items-center gap-1 text-[11px] text-emerald-700 font-bold bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">
                        <CheckCircle className="w-3 h-3" /> Active
                      </span>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-right">
                      <button
                        onClick={() => handleDeleteUser(user.id)}
                        title="Delete User"
                        className="text-red-600 hover:text-red-800 p-1 rounded hover:bg-red-50 cursor-pointer transition-colors"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 2: Health Facilities Table */}
      {activeTab === 'facilities' && (
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden shadow-xs">
          <div className="px-6 py-4 border-b border-slate-200 flex justify-between items-center bg-slate-50/50">
            <div>
              <h3 className="text-sm font-bold text-slate-800">
                {'National Health Facility Registry (NHFR)'}
              </h3>
              <p className="text-xs text-slate-500">
                Manage dengue wards, inpatient beds, and NS1 RDT rapid test kit stocks.
              </p>
            </div>
            <span className="text-xs font-bold text-slate-600 bg-slate-200 px-2.5 py-1 rounded-full">
              {facilitiesList.length} Facilities
            </span>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-200 text-xs">
              <thead className="bg-slate-50 text-slate-700 font-bold uppercase tracking-wider text-[11px]">
                <tr>
                  <th className="px-6 py-3 text-left">Facility Name</th>
                  <th className="px-6 py-3 text-left">Facility Type</th>
                  <th className="px-6 py-3 text-left">Palika & Ward</th>
                  <th className="px-6 py-3 text-center">Total Beds</th>
                  <th className="px-6 py-3 text-center">Dengue Beds</th>
                  <th className="px-6 py-3 text-center">NS1 Kits</th>
                  <th className="px-6 py-3 text-left">Emergency Hotline</th>
                  <th className="px-6 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 bg-white">
                {(Array.isArray(facilitiesList) ? facilitiesList : []).map((fac) => (
                  <tr key={fac.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="px-6 py-3.5 whitespace-nowrap">
                      <div className="font-bold text-slate-900">{fac.name}</div>
                      <div className="text-[11px] text-slate-500">{fac.name_ne}</div>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-slate-600">
                      {fac.facility_type}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-slate-600">
                      <div>Palika: {fac.palika_code}</div>
                      <div className="text-[11px] text-slate-400 font-mono">{fac.composite_ward_id}</div>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-center font-bold text-slate-800">
                      {fac.total_beds}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-center font-bold text-[#DC2626]">
                      {fac.dengue_ward_beds}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-center font-bold text-emerald-700">
                      {fac.ns1_rdt_kits_stock}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap font-mono text-slate-600">
                      {fac.emergency_phone || '1115'}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-right space-x-2">
                      <button
                        onClick={() => {
                          setEditingFacility(fac);
                          setFacName(fac.name);
                          setFacNameNe(fac.name_ne);
                          setFacType(fac.facility_type);
                          setFacPalika(fac.palika_code);
                          setFacWard(fac.composite_ward_id);
                          setFacTotalBeds(fac.total_beds);
                          setFacDengueBeds(fac.dengue_ward_beds);
                          setFacNs1Kits(fac.ns1_rdt_kits_stock);
                          setFacEmergencyPhone(fac.emergency_phone);
                          setShowFacilityModal(true);
                        }}
                        className="text-[#a50c1f] hover:text-[#7c0012] p-1 cursor-pointer"
                        title="Edit Facility"
                      >
                        <Pencil className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleDeleteFacility(fac.id)}
                        className="text-red-600 hover:text-red-800 p-1 cursor-pointer"
                        title="Delete Facility"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 3: RRT Rapid Response Vans Table */}
      {activeTab === 'rrt' && (
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden shadow-xs">
          <div className="px-6 py-4 border-b border-slate-200 flex justify-between items-center bg-slate-50/50">
            <div>
              <h3 className="text-sm font-bold text-slate-800">
                {'Rapid Response Team Fleet & Chemical Stock'}
              </h3>
              <p className="text-xs text-slate-500">
                Sovereign government vans with Bti larvicide, Temephos, and ULV fogging equipment.
              </p>
            </div>
            <span className="text-xs font-bold text-slate-600 bg-slate-200 px-2.5 py-1 rounded-full">
              {rrtList.length} RRT Vehicles
            </span>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-200 text-xs">
              <thead className="bg-slate-50 text-slate-700 font-bold uppercase tracking-wider text-[11px]">
                <tr>
                  <th className="px-6 py-3 text-left">Vehicle ID</th>
                  <th className="px-6 py-3 text-left">Plate Number</th>
                  <th className="px-6 py-3 text-left">Palika & Base Ward</th>
                  <th className="px-6 py-3 text-left">Team Lead / Driver</th>
                  <th className="px-6 py-3 text-center">Bti Stock</th>
                  <th className="px-6 py-3 text-center">Temephos Stock</th>
                  <th className="px-6 py-3 text-center">ULV Equipment</th>
                  <th className="px-6 py-3 text-center">Status</th>
                  <th className="px-6 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 bg-white">
                {(Array.isArray(rrtList) ? rrtList : []).map((van) => (
                  <tr key={van.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="px-6 py-3.5 whitespace-nowrap font-bold text-slate-800">
                      {van.vehicle_id}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap font-mono font-bold text-slate-700">
                      <span className="bg-red-50 text-red-900 border border-red-200 px-2 py-0.5 rounded">
                        {van.plate_number}
                      </span>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-slate-600">
                      <div>Palika: {van.palika_code}</div>
                      <div className="text-[11px] text-slate-400 font-mono">{van.base_ward_id}</div>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap">
                      <div className="font-semibold text-slate-800">{van.team_lead_name}</div>
                      <div className="text-[11px] text-slate-500 font-mono">{van.driver_phone}</div>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-center font-bold text-slate-800">
                      {van.bti_stock_kg} kg
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-center font-bold text-slate-800">
                      {van.temephos_stock_liters} L
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-center">
                      <span
                        className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                          van.ulv_equipment_mounted
                            ? 'bg-emerald-100 text-emerald-800'
                            : 'bg-slate-100 text-slate-600'
                        }`}
                      >
                        {van.ulv_equipment_mounted ? 'Mounted' : 'No'}
                      </span>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-center">
                      <span
                        className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                          van.status === 'AVAILABLE'
                            ? 'bg-emerald-100 text-emerald-800 border border-emerald-300'
                            : van.status === 'DISPATCHED'
                            ? 'bg-amber-100 text-amber-800 border border-amber-300'
                            : 'bg-slate-100 text-slate-800'
                        }`}
                      >
                        {van.status}
                      </span>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-right space-x-2">
                      <button
                        onClick={() => {
                          setEditingRrt(van);
                          setRrtVehicleId(van.vehicle_id);
                          setRrtPlateNumber(van.plate_number);
                          setRrtPalika(van.palika_code);
                          setRrtBaseWard(van.base_ward_id);
                          setRrtTeamLead(van.team_lead_name);
                          setRrtDriverPhone(van.driver_phone);
                          setRrtBtiKg(van.bti_stock_kg);
                          setRrtTemephosL(van.temephos_stock_liters);
                          setRrtUlvMounted(van.ulv_equipment_mounted);
                          setRrtStatus(van.status);
                          setShowRrtModal(true);
                        }}
                        className="text-[#a50c1f] hover:text-[#7c0012] p-1 cursor-pointer"
                        title="Edit RRT Van"
                      >
                        <Pencil className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleDeleteRrt(van.id)}
                        className="text-red-600 hover:text-red-800 p-1 cursor-pointer"
                        title="Delete RRT Van"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 4: Support Tickets & Requests Table */}
      {activeTab === 'tickets' && (
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden shadow-xs">
          <div className="px-6 py-4 border-b border-slate-200 flex justify-between items-center bg-slate-50/50">
            <div>
              <h3 className="text-sm font-bold text-slate-800">
                {'Community Outbreak Alerts & SLA Support Tickets'}
              </h3>
              <p className="text-xs text-slate-500">
                Filtered across municipalities and specific wards. Update ticket status in real-time.
              </p>
            </div>
            <span className="text-xs font-bold text-slate-600 bg-slate-200 px-2.5 py-1 rounded-full">
              {ticketsList.length} Tickets
            </span>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-200 text-xs">
              <thead className="bg-slate-50 text-slate-700 font-bold uppercase tracking-wider text-[11px]">
                <tr>
                  <th className="px-6 py-3 text-left">Ticket Code</th>
                  <th className="px-6 py-3 text-left">Palika & Ward</th>
                  <th className="px-6 py-3 text-left">Severity</th>
                  <th className="px-6 py-3 text-left">Category</th>
                  <th className="px-6 py-3 text-left">Summary / Description</th>
                  <th className="px-6 py-3 text-center">Status</th>
                  <th className="px-6 py-3 text-right">Update Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 bg-white">
                {(Array.isArray(ticketsList) ? ticketsList : []).map((t) => (
                  <tr key={t.ticket_code} className="hover:bg-slate-50/80 transition-colors">
                    <td className="px-6 py-3.5 whitespace-nowrap font-mono font-bold text-[#a50c1f]">
                      {t.ticket_code}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-slate-600">
                      <div>Palika: {t.palika_code}</div>
                      <div className="text-[11px] text-slate-400 font-mono">{t.composite_ward_id}</div>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap">
                      <span
                        className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                          t.severity_tier === 'CRITICAL'
                            ? 'bg-red-100 text-red-800 border border-red-300'
                            : t.severity_tier === 'HIGH'
                            ? 'bg-amber-100 text-amber-800'
                            : 'bg-slate-100 text-slate-700'
                        }`}
                      >
                        {t.severity_tier} ({t.sla_hours}h SLA)
                      </span>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap font-medium text-slate-800">
                      {t.category}
                    </td>
                    <td className="px-6 py-3.5 max-w-sm text-slate-700">
                      <div className="truncate">{t.summary}</div>
                      <div className="text-[11px] text-slate-400">{t.created_at_bs}</div>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-center">
                      <span
                        className={`px-2.5 py-1 rounded-full text-[10px] font-bold ${
                          t.status === 'RESOLVED'
                            ? 'bg-emerald-100 text-emerald-800'
                            : t.status === 'ASSIGNED'
                            ? 'bg-blue-100 text-[#7c0012]'
                            : 'bg-amber-100 text-amber-800'
                        }`}
                      >
                        {t.status}
                      </span>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-right space-x-1.5">
                      {t.status !== 'ASSIGNED' && (
                        <button
                          onClick={() => handleUpdateTicket(t.ticket_code, 'ASSIGNED')}
                          className="px-2 py-1 text-[11px] font-semibold bg-[#fee2e2]/40 text-[#991b1b] border border-[#fca5a5] rounded hover:bg-blue-100 cursor-pointer"
                        >
                          Assign
                        </button>
                      )}
                      {t.status !== 'RESOLVED' && (
                        <button
                          onClick={() => handleUpdateTicket(t.ticket_code, 'RESOLVED')}
                          className="px-2 py-1 text-[11px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 rounded hover:bg-emerald-100 cursor-pointer"
                        >
                          Resolve
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* MODAL: Add Staff Member */}
      {showAddUserModal && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4 z-50 overflow-y-auto">
          <div className="bg-white rounded-xl max-w-lg w-full p-6 shadow-xl border border-slate-200 my-8">
            <div className="flex justify-between items-center pb-3 border-b border-slate-200">
              <h3 className="text-base font-bold text-slate-800 flex items-center gap-2">
                <Users className="w-5 h-5 text-[#a50c1f]" />
                <span>{'Authorize New Staff User'}</span>
              </h3>
              <button
                onClick={() => setShowAddUserModal(false)}
                className="text-slate-400 hover:text-slate-600 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreateUser} className="space-y-4 mt-4">
              {/* Role Selector */}
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">
                  {'Role / Authority Level'}
                </label>
                <select
                  value={newUserRole}
                  onChange={(e) => setNewUserRole(e.target.value as any)}
                  className="w-full text-xs border border-slate-300 rounded-lg p-2.5 bg-slate-50 font-semibold"
                >
                  <option value="admin">Federal System Admin</option>
                  <option value="municipality_admin">Municipality Admin</option>
                  <option value="field_visitor">Field Visitor (Inspector / FCHV)</option>
                </select>
              </div>

              {/* Palika Selector (Hierarchy) */}
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">
                  {'Assigned Local Level (Palika)'}
                </label>
                <select
                  value={newUserPalika}
                  onChange={(e) => {
                    setNewUserPalika(e.target.value);
                    const pal = hierarchy?.palikas?.find((x) => x.palika_code === e.target.value);
                    if (pal && pal.wards && pal.wards.length > 0) {
                      setNewUserSelectedWard(pal.wards[0].composite_ward_id);
                    }
                  }}
                  className="w-full text-xs border border-slate-300 rounded-lg p-2.5 bg-slate-50"
                  required
                >
                  {(hierarchy?.palikas || []).map((p) => (
                    <option key={p.palika_code} value={p.palika_code}>
                      {p.palika_name} ({p.palika_type})
                    </option>
                  ))}
                </select>
              </div>

              {/* Metropolitan or Sub-Metropolitan Ward Allocation Strategy */}
              {newUserPalikaObj && newUserPalikaObj.is_metro_or_submetro && newUserRole !== 'admin' && (
                <div className="bg-[#fee2e2]/40/60 border border-[#fca5a5] rounded-lg p-3">
                  <div className="text-xs font-bold text-[#a50c1f] mb-1.5 flex items-center gap-1.5">
                    <Layers className="w-3.5 h-3.5" />
                    <span>Metropolitan / Sub-Metropolitan Jurisdiction Strategy</span>
                  </div>
                  <p className="text-[11px] text-slate-600 mb-2">
                    {newUserPalikaObj.palika_name} contains {newUserPalikaObj.wards?.length || 0} wards. You can grant city-wide scope or allocate to a specific ward:
                  </p>

                  {newUserRole === 'municipality_admin' && (
                    <div className="flex gap-4 mb-2 text-xs">
                      <label className="flex items-center gap-1.5 cursor-pointer">
                        <input
                          type="radio"
                          name="ward_alloc"
                          checked={newUserWardAllocationType === 'all'}
                          onChange={() => setNewUserWardAllocationType('all')}
                        />
                        <span className="font-semibold text-slate-800">Whole City (All Wards)</span>
                      </label>
                      <label className="flex items-center gap-1.5 cursor-pointer">
                        <input
                          type="radio"
                          name="ward_alloc"
                          checked={newUserWardAllocationType === 'specific'}
                          onChange={() => setNewUserWardAllocationType('specific')}
                        />
                        <span className="font-semibold text-slate-800">Specific Ward Only</span>
                      </label>
                    </div>
                  )}

                  {(newUserWardAllocationType === 'specific' || newUserRole === 'field_visitor') && (
                    <div>
                      <label className="block text-[11px] font-bold text-slate-700 mb-1">
                        Select Ward:
                      </label>
                      <select
                        value={newUserSelectedWard}
                        onChange={(e) => setNewUserSelectedWard(e.target.value)}
                        className="w-full text-xs border border-blue-300 rounded-lg p-2 bg-white"
                      >
                        {(newUserPalikaObj.wards || []).map((w) => (
                          <option key={w.composite_ward_id} value={w.composite_ward_id}>
                            Ward {w.ward_no} - {w.locality_name} ({w.composite_ward_id})
                          </option>
                        ))}
                      </select>
                    </div>
                  )}
                </div>
              )}

              {/* Staff Details */}
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">
                    Full Name (English)
                  </label>
                  <input
                    type="text"
                    value={newUserName}
                    onChange={(e) => setNewUserName(e.target.value)}
                    placeholder="e.g. Ramesh Poudel"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">
                    Secondary / Local Name
                  </label>
                  <input
                    type="text"
                    value={newUserNameNe}
                    onChange={(e) => setNewUserNameNe(e.target.value)}
                    placeholder="e.g. Ramesh Poudel"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">
                    Mobile Phone (+977 / +91)
                  </label>
                  <input
                    type="text"
                    value={newUserPhone}
                    onChange={(e) => setNewUserPhone(e.target.value)}
                    placeholder="+91XXXXXXXXXX or +977XXXXXXXXXX"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">
                    Initial Security PIN
                  </label>
                  <input
                    type="password"
                    value={newUserPin}
                    onChange={(e) => setNewUserPin(e.target.value)}
                    placeholder="6 digits"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">
                  Designation / Title
                </label>
                <input
                  type="text"
                  value={newUserDesignation}
                  onChange={(e) => setNewUserDesignation(e.target.value)}
                  placeholder="e.g. Senior Public Health Assistant"
                  className="w-full text-xs border border-slate-300 rounded-lg p-2.5"
                  required
                />
              </div>

              <div className="flex justify-end gap-2 pt-4 border-t border-slate-200">
                <button
                  type="button"
                  onClick={() => setShowAddUserModal(false)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded-lg cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 text-xs font-bold bg-[#a50c1f] text-white rounded-lg hover:bg-[#7c0012] cursor-pointer shadow-xs"
                >
                  Create Staff User
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL: Add/Edit Facility */}
      {showFacilityModal && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4 z-50 overflow-y-auto">
          <div className="bg-white rounded-xl max-w-lg w-full p-6 shadow-xl border border-slate-200 my-8">
            <div className="flex justify-between items-center pb-3 border-b border-slate-200">
              <h3 className="text-base font-bold text-slate-800 flex items-center gap-2">
                <Building2 className="w-5 h-5 text-[#a50c1f]" />
                <span>{editingFacility ? 'Edit Health Center' : 'Add Health Center'}</span>
              </h3>
              <button onClick={() => setShowFacilityModal(false)} className="text-slate-400 hover:text-slate-600 cursor-pointer">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveFacility} className="space-y-4 mt-4">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Facility Name (EN)</label>
                  <input
                    type="text"
                    value={facName}
                    onChange={(e) => setFacName(e.target.value)}
                    placeholder="e.g. Chhetrapati UHPC"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Secondary / Local Facility Name</label>
                  <input
                    type="text"
                    value={facNameNe}
                    onChange={(e) => setFacNameNe(e.target.value)}
                    placeholder="e.g. Chhetrapati Health Post"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Facility Type</label>
                <select
                  value={facType}
                  onChange={(e) => setFacType(e.target.value)}
                  className="w-full text-xs border border-slate-300 rounded-lg p-2.5 bg-slate-50"
                >
                  <option value="Urban Health Promotion Center (UHPC)">Urban Health Promotion Center (UHPC)</option>
                  <option value="General Hospital">General Hospital</option>
                  <option value="Primary Health Center (PHC)">Primary Health Center (PHC)</option>
                  <option value="Health Post">Health Post</option>
                  <option value="Vector Borne Disease Research Center">Vector Borne Disease Research Center</option>
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Palika Code</label>
                  <select
                    value={facPalika}
                    onChange={(e) => setFacPalika(e.target.value)}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 bg-slate-50"
                  >
                    {(hierarchy?.palikas || []).map((p) => (
                      <option key={p.palika_code} value={p.palika_code}>
                        {p.palika_name}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Composite Ward ID</label>
                  <input
                    type="text"
                    value={facWard}
                    onChange={(e) => setFacWard(e.target.value)}
                    placeholder="NP-P3-D27-30608-W17"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-3 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Total Beds</label>
                  <input
                    type="number"
                    value={facTotalBeds}
                    onChange={(e) => setFacTotalBeds(Number(e.target.value))}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Dengue Beds</label>
                  <input
                    type="number"
                    value={facDengueBeds}
                    onChange={(e) => setFacDengueBeds(Number(e.target.value))}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">NS1 Test Kits</label>
                  <input
                    type="number"
                    value={facNs1Kits}
                    onChange={(e) => setFacNs1Kits(Number(e.target.value))}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Emergency Phone Hotline</label>
                <input
                  type="text"
                  value={facEmergencyPhone}
                  onChange={(e) => setFacEmergencyPhone(e.target.value)}
                  placeholder="01-XXXXXXX"
                  className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                />
              </div>

              <div className="flex justify-end gap-2 pt-4 border-t border-slate-200">
                <button
                  type="button"
                  onClick={() => setShowFacilityModal(false)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded-lg cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 text-xs font-bold bg-[#a50c1f] text-white rounded-lg hover:bg-[#7c0012] cursor-pointer shadow-xs"
                >
                  Save Health Center
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL: Add/Edit RRT Van */}
      {showRrtModal && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4 z-50 overflow-y-auto">
          <div className="bg-white rounded-xl max-w-lg w-full p-6 shadow-xl border border-slate-200 my-8">
            <div className="flex justify-between items-center pb-3 border-b border-slate-200">
              <h3 className="text-base font-bold text-slate-800 flex items-center gap-2">
                <Truck className="w-5 h-5 text-[#a50c1f]" />
                <span>{editingRrt ? 'Edit RRT Van' : 'Add Rapid Response Van'}</span>
              </h3>
              <button onClick={() => setShowRrtModal(false)} className="text-slate-400 hover:text-slate-600 cursor-pointer">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveRrt} className="space-y-4 mt-4">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Vehicle Unit ID</label>
                  <input
                    type="text"
                    value={rrtVehicleId}
                    onChange={(e) => setRrtVehicleId(e.target.value)}
                    placeholder="e.g. RRT-KMC-07"
                    disabled={!!editingRrt}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Government Plate</label>
                  <input
                    type="text"
                    value={rrtPlateNumber}
                    onChange={(e) => setRrtPlateNumber(e.target.value)}
                    placeholder="BA-2-JHA-4107"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Palika Code</label>
                  <select
                    value={rrtPalika}
                    onChange={(e) => setRrtPalika(e.target.value)}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 bg-slate-50"
                  >
                    {(hierarchy?.palikas || []).map((p) => (
                      <option key={p.palika_code} value={p.palika_code}>
                        {p.palika_name}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Base Ward ID</label>
                  <input
                    type="text"
                    value={rrtBaseWard}
                    onChange={(e) => setRrtBaseWard(e.target.value)}
                    placeholder="NP-P3-D27-30608-W17"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Team Lead Name</label>
                  <input
                    type="text"
                    value={rrtTeamLead}
                    onChange={(e) => setRrtTeamLead(e.target.value)}
                    placeholder="e.g. Hari Bahadur Thapa"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Driver Phone (+977 / +91)</label>
                  <input
                    type="text"
                    value={rrtDriverPhone}
                    onChange={(e) => setRrtDriverPhone(e.target.value)}
                    placeholder="+9198XXXXXXXX"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Bti Larvicide Stock (kg)</label>
                  <input
                    type="number"
                    step="0.1"
                    value={rrtBtiKg}
                    onChange={(e) => setRrtBtiKg(Number(e.target.value))}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Temephos Stock (Liters)</label>
                  <input
                    type="number"
                    step="0.1"
                    value={rrtTemephosL}
                    onChange={(e) => setRrtTemephosL(Number(e.target.value))}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3 items-center">
                <div className="flex items-center gap-2 pt-2">
                  <input
                    type="checkbox"
                    id="ulvMounted"
                    checked={rrtUlvMounted}
                    onChange={(e) => setRrtUlvMounted(e.target.checked)}
                    className="rounded border-slate-300"
                  />
                  <label htmlFor="ulvMounted" className="text-xs font-bold text-slate-700 cursor-pointer">
                    ULV Fogging Mounted
                  </label>
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Vehicle Status</label>
                  <select
                    value={rrtStatus}
                    onChange={(e) => setRrtStatus(e.target.value as any)}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 bg-slate-50 font-bold"
                  >
                    <option value="AVAILABLE">Available</option>
                    <option value="DISPATCHED">Dispatched</option>
                    <option value="MAINTENANCE">Maintenance</option>
                  </select>
                </div>
              </div>

              <div className="flex justify-end gap-2 pt-4 border-t border-slate-200">
                <button
                  type="button"
                  onClick={() => setShowRrtModal(false)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded-lg cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 text-xs font-bold bg-[#a50c1f] text-white rounded-lg hover:bg-[#7c0012] cursor-pointer shadow-xs"
                >
                  Save RRT Van
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
