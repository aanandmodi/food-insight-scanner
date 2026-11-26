export type AiTaskKey = 'chat' | 'meal' | 'plan' | 'analysis' | 'macros' | 'quickReplies';

export interface FeatureFlags {
  aiEnabled?: boolean;
  aiChatEnabled?: boolean;
  mealPlannerEnabled?: boolean;
  aiMealPlannerEnabled?: boolean;
  aiProductAnalysisEnabled?: boolean;
  aiMealParserEnabled?: boolean;
  aiRecalibrationEnabled?: boolean;
  aiQuickRepliesEnabled?: boolean;
  additiveInsightsEnabled?: boolean;
  alternativesEnabled?: boolean;
  maintenanceMode?: boolean;
  maintenanceMessage?: string;
  minAppVersion?: string;
  requiredTermsVersion?: string;
  requiredPrivacyVersion?: string;
  aiIpPerMinuteLimit?: number;
  macroMaxAdjustmentPercent?: number;
  aiDailyLimits?: Partial<Record<AiTaskKey, number>>;
  updatedBy?: string;
  updatedAt?: string;
}

export interface ProviderHealthRow {
  provider: string;
  cooldown_until: string | null;
  consecutive_failures: number;
  last_status: number | null;
  last_error_at: string | null;
  updated_at?: string | null;
}

export interface OverviewResponse {
  flags: FeatureFlags;
  providerHealth: ProviderHealthRow[];
  metrics: {
    recentAbuseCount: number;
    openReportsCount: number;
    pendingDeletionsCount: number;
    aiRequestsToday: number;
    activeQuotaUsersToday: number;
    auditEntriesSampled: number;
  };
  admin: { uid: string; email: string };
}

export interface UserQuotaRow {
  user_id: string;
  task: string;
  day_date: string;
  daily_count: number;
  last_request_at?: string | null;
}

export interface IpRateLimitRow {
  ip_hash: string;
  window_start: string;
  request_count: number;
}

export interface AbuseEvent {
  id: string;
  user_id: string;
  task: string;
  category: string;
  severity: 'low' | 'medium' | 'high' | string;
  rule_id: string;
  snippet: string;
  created_at: string;
}

export interface UserLookupResult {
  uid: string;
  authUser: {
    uid: string;
    email: string | null;
    emailVerified: boolean;
    disabled: boolean;
    displayName: string | null;
    providers: string[];
    createdAt: string | null;
    lastSignInAt: string | null;
    customClaims: Record<string, unknown>;
  } | null;
  profile: Record<string, unknown> | null;
  consents: Array<Record<string, unknown>>;
  quotas: UserQuotaRow[];
  abuseEvents: AbuseEvent[];
  suspended: boolean;
  suspension: Record<string, unknown> | null;
  deletionInProgress: boolean;
}

export interface DeletionRequest {
  id: string;
  request_email: string;
  target_uid: string;
  source: 'web_email' | 'support' | 'admin' | string;
  notes: string;
  status: 'pending' | 'completed' | 'rejected' | string;
  resolution_note: string;
  resolved_by: string;
  created_at: string;
  resolved_at: string | null;
}

export interface ProductReport {
  id: string;
  user_id: string;
  barcode: string;
  product_name: string;
  issue_type: string;
  notes: string;
  status: 'open' | 'resolved' | 'dismissed' | string;
  resolution_note: string;
  resolved_by: string;
  created_at: string;
  resolved_at: string | null;
}

export interface CanonicalProduct {
  barcode: string;
  name: string;
  brand?: string;
  category?: string;
  ingredientsText?: string;
  ingredients?: string[];
  allergens?: string[];
  traces?: string[];
  additives?: string[];
  nutriscore?: string | null;
  nutrition?: {
    energyKcalPer100g?: number | null;
    proteinGPer100g?: number | null;
    carbohydratesGPer100g?: number | null;
    sugarGPer100g?: number | null;
    fatGPer100g?: number | null;
    fiberGPer100g?: number | null;
    sodiumMgPer100g?: number | null;
  };
  adminVerified?: boolean;
  adminVerifiedBy?: string;
  adminVerifiedAt?: string;
}

export interface AdditiveOverride {
  ins: string;
  name: string;
  category: string;
  safety_tier: 'low' | 'caution' | 'avoid' | 'info' | string;
  summary: string;
  dietary_notes: string;
  active: boolean;
  updated_by?: string;
  updated_at?: string;
}

export interface AuditLogEntry {
  id: string;
  admin_uid: string;
  admin_email: string;
  action: string;
  target_type: string;
  target_id: string;
  details: Record<string, unknown>;
  created_at: string;
}
