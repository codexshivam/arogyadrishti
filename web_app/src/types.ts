export type UserRole =
  | 'admin'
  | 'municipality_admin'
  | 'field_visitor'
  | 'fchv'
  | 'ward_health_officer'
  | 'palika_health_chief'
  | 'edcd_nodal';

export interface UserProfile {
  id: string;
  phone: string;
  full_name: string;
  full_name_ne: string;
  designation: string;
  role: UserRole;
  province_code: number;
  district_code: number;
  palika_code: string;
  assigned_wards: string[];
  bs_date: string;
  bs_ad_official_label: string;
  token: string;
}

export interface WardOption {
  composite_ward_id: string;
  ward_no: number;
  locality_name: string;
  locality_name_np: string;
}

export interface PalikaOption {
  palika_code: string;
  palika_name: string;
  palika_name_np: string;
  palika_type: 'Metropolitan City' | 'Sub-Metropolitan City' | 'Municipality' | 'Rural Municipality' | string;
  is_metro_or_submetro: boolean;
  province_code: number;
  province_name: string;
  province_name_np: string;
  district_code: number;
  district_name: string;
  district_name_np: string;
  wards: WardOption[];
}

export interface AdministrativeHierarchy {
  provinces: any[];
  palikas: PalikaOption[];
  bs_date: string;
  bs_ad_official_label: string;
}

export interface StaffUserItem {
  id: string;
  phone: string;
  full_name: string;
  full_name_ne: string;
  designation: string;
  role: string;
  province_code: number;
  district_code: number;
  palika_code: string;
  assigned_wards: string[];
  is_active: boolean;
  created_at_bs?: string;
}

export interface HealthFacilityItem {
  id: string;
  facility_id: string;
  name: string;
  name_ne: string;
  facility_type: string;
  province_code: number;
  district_code: number;
  palika_code: string;
  composite_ward_id: string;
  status: string;
  total_beds: number;
  dengue_ward_beds: number;
  ns1_rdt_kits_stock: number;
  emergency_phone: string;
  hello_swasthya_hotline: string;
}

export interface RrtVehicleItem {
  id: string;
  vehicle_id: string;
  plate_number: string;
  palika_code: string;
  base_ward_id: string;
  team_lead_name: string;
  team_lead_name_ne: string;
  driver_phone: string;
  bti_stock_kg: number;
  temephos_stock_liters: number;
  ulv_equipment_mounted: boolean;
  status: 'AVAILABLE' | 'DISPATCHED' | 'MAINTENANCE';
  base_lat?: number;
  base_lng?: number;
}

export interface EscalationTicketItem {
  ticket_code: string;
  composite_ward_id: string;
  palika_code: string;
  severity_tier: string;
  sla_hours: number;
  category: string;
  summary: string;
  status: 'OPEN' | 'ASSIGNED' | 'RESOLVED';
  created_at_bs: string;
}
