# Implementation Plan: Updated Offline Camp Synchronization

This plan outlines the steps to align the Flutter application with the updated backend camp synchronization module.

## 1. Overview of Changes

The backend has transitioned from a simple device registration to a more secure, camp-centric authentication model. Tablets must now:
1.  Discover active camps.
2.  Authenticate with a camp-specific password.
3.  Receive a session-specific `device_token`.
4.  Perform bootstrap and bulk sync using this token.

## 2. API Alignment

| Feature | Old Endpoint | New Endpoint | Change Status |
| :--- | :--- | :--- | :--- |
| **Discovery** | N/A | `GET /available-camps` | New |
| **Authentication** | `POST /register-device` | `POST /select-camp` | Replacement |
| **Bootstrap** | `GET /bootstrap/:campId` | `GET /bootstrap/:campId` | Refine Mappings |
| **Bulk Sync** | `POST /bulk-sync` | `POST /bulk-sync` | Refine Reconciliation |

## 3. Implementation Steps

### Phase 1: Core Service Updates (`CampSyncService`)
- [ ] **Implement `fetchAvailableCamps`**:
    - Call `GET /api/camp-sync/available-camps`.
    - No authentication required for this list.
- [ ] **Implement `selectCamp`**:
    - Call `POST /api/camp-sync/select-camp`.
    - Body: `{ camp_id, password, device_name, device_identifier }`.
    - Securely store the returned `auth_token` using `AuthStorageService`.
    - Save camp metadata (name, prefix) to `camp_config` table.
- [ ] **Refine `bootstrap`**:
    - Ensure all fields from `diagnosis_catalog` are correctly mapped to `master_diagnosis`.
    - Handle both `diagnosisQuestions` (legacy) and `diagnosis_catalog` keys.
- [ ] **Refine `bulkSync`**:
    - Improve error reconciliation: specifically mark rows as `failed` with the exact server reason.
    - Ensure `device_uuid` is used consistently for all mappings.

### Phase 2: State Management Updates (`SyncProvider`)
- [ ] **Update `registerDevice` logic**:
    - Replace the internal logic to use `selectCamp`.
- [ ] **Add `fetchCamps` method**:
    - Expose the available camps list to the UI.
- [ ] **Refine `bootstrap` flow**:
    - Clear local master data before reloading to ensure no stale records remain from previous camps.

### Phase 3: UI Updates (`lib/screens/sync`)
- [ ] **Camp Selection Screen**:
    - Create/Update a screen to list available camps.
    - Add a password dialog prompt when a camp is selected.
- [ ] **Sync Dashboard**:
    - Display the current active camp name and MR prefix.
    - Improve the "Failed Records" view to show server-side validation errors.

### Phase 4: Database & Models
- [ ] **Schema Check**:
    - Verify `camp_config` table has all necessary fields (it already seems to have `device_token` and `mr_prefix`).
    - Ensure `last_error` columns in transactional tables are effectively used to show sync failures.

## 4. Testing Strategy
1.  **Connectivity**: Test behavior with "Force Offline" mode on/off.
2.  **Authentication**: Validate correct vs. incorrect password handling.
3.  **Data Integrity**: Verify that UUIDs remain constant across sync retries.
4.  **Bulk Processing**: Sync a mix of 10+ records with some intentionally invalid data to test per-record error handling.

---
**Next Action**: Upon approval, I will begin implementing Phase 1 in `lib/core/services/camp_sync_service.dart`.
