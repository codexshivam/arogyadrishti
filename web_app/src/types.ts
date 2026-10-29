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

export interface FieldInspectionItem {
  id: string;
  client_submission_uuid: string;
  composite_ward_id: string;
  palika_code: string;
  inspector_id: string;
  houses_inspected: number;
  houses_infested: number;
  wet_containers_inspected: number;
  positive_containers: number;
  pupae_count: number;
  container_type: string;
  larvicide_applied: string;
  exact_latitude?: number;
  exact_longitude?: number;
  public_grid_lat?: number;
  public_grid_lng?: number;
  inspected_at_bs: string;
}

export interface PoeSurveillanceItem {
  id: string;
  poe_desk_code: string;
  poe_name: string;
  disease: string;
  rdt_result: string;
  origin_zone: string;
  destination_province_code: number;
  destination_palika_code: string;
  destination_ward_no: number;
  destination_composite_ward_id: string;
  destination_alert_dispatched: boolean;
  alert_ticket_code: string;
  focal_response_directive_en?: string;
  logged_at_bs: string;
}

export interface WardRiskItem {
  composite_ward_id: string;
  ward_no: number;
  palika_code: string;
  palika_name: string;
  locality_name: string;
  risk_tier: string;
  composite_risk_score: number;
  breteau_index_bi: number;
  house_index_hi: number;
  container_index_ci: number;
  active_search_and_destroy_count?: number;
  breeding_sites_neutralized_month?: number;
}

export interface ElmisCommodityItem {
  commodity_code: string;
  commodity_name_ne?: string;
  unit: string;
  current_stock: number;
  daily_baseline_burn: number;
  projected_daily_outbreak_burn: number;
  days_remaining: number;
  stockout_imminent: boolean;
  recommended_reorder_qty: number;
}

export interface ElmisForecastData {
  palika_code: string;
  phlmc_hub_name: string;
  outbreak_surge_multiplier: number;
  commodities: ElmisCommodityItem[];
  auto_requisitions: any[];
}
