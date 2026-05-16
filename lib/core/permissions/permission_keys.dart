// All permission keys matching backend seed data.
// Format: MODULE_CODE.RESOURCE_CODE.ACTION_CODE
// Aligned with React WaseelaHIMS-F App.jsx permissions.
class Perm {
  // ─── OPD Module ───────────────────────────────────────────────────────────
  static const opdPatientRead    = 'OPD.PATIENT.READ';
  static const opdPatientCreate  = 'OPD.PATIENT.CREATE';
  static const opdPatientUpdate  = 'OPD.PATIENT.UPDATE';
  static const opdPatientCancel  = 'OPD.PATIENT.CANCEL';
  static const opdPatientRefund  = 'OPD.PATIENT.REFUND';
  static const opdPatientPrint   = 'OPD.PATIENT.PRINT';

  static const opdReceiptRead    = 'OPD.RECEIPT.READ';
  static const opdReceiptCreate  = 'OPD.RECEIPT.CREATE';
  static const opdReceiptUpdate  = 'OPD.RECEIPT.UPDATE';
  static const opdReceiptCancel  = 'OPD.RECEIPT.CANCEL';
  static const opdReceiptRefund  = 'OPD.RECEIPT.REFUND';
  static const opdReceiptPrint   = 'OPD.RECEIPT.PRINT';

  static const opdShiftCreate    = 'OPD.SHIFT.CREATE';
  static const opdShiftRead      = 'OPD.SHIFT.READ';
  static const opdShiftClose     = 'OPD.SHIFT.CLOSE';

  static const opdShiftCashRead   = 'OPD.SHIFT_CASH.READ';
  static const opdShiftCashUpdate = 'OPD.SHIFT_CASH.UPDATE';
  static const opdShiftCashClose  = 'OPD.SHIFT_CASH.CLOSE';
  static const opdShiftCashPrint  = 'OPD.SHIFT_CASH.PRINT';

  static const opdServicesRead    = 'OPD.SERVICES.READ';
  static const opdServicesCreate  = 'OPD.SERVICES.CREATE';
  static const opdServicesUpdate  = 'OPD.SERVICES.UPDATE';
  static const opdServicesDelete  = 'OPD.SERVICES.DELETE';

  static const opdReportsRead     = 'OPD.REPORTS.READ';
  static const opdReportsPrint    = 'OPD.REPORTS.PRINT';

  // FIX: was using opdReceiptRead+setupDiscountTypeRead — React uses OPD.DISCOUNT_APPROVAL.READ
  static const opdDiscountApprovalRead = 'OPD.DISCOUNT_APPROVAL.READ';

  // ─── App ──────────────────────────────────────────────────────────────────
  static const appDashboardRead      = 'APP.DASHBOARD.READ';
  static const appLegacyImportRead   = 'APP.LEGACY_IMPORT.READ';
  static const appLegacyImportCreate = 'APP.LEGACY_IMPORT.CREATE';

  // ─── Appointments ─────────────────────────────────────────────────────────
  static const apptRead    = 'APPOINTMENTS.APPOINTMENT.READ';
  static const apptCreate  = 'APPOINTMENTS.APPOINTMENT.CREATE';
  static const apptUpdate  = 'APPOINTMENTS.APPOINTMENT.UPDATE';
  static const apptDelete  = 'APPOINTMENTS.APPOINTMENT.DELETE';

  // ─── Doctors ──────────────────────────────────────────────────────────────
  static const doctorsRead   = 'DOCTORS.DOCTOR.READ';
  static const doctorsCreate = 'DOCTORS.DOCTOR.CREATE';
  static const doctorsUpdate = 'DOCTORS.DOCTOR.UPDATE';
  static const doctorsDelete = 'DOCTORS.DOCTOR.DELETE';

  // ─── Employees (NEW) ──────────────────────────────────────────────────────
  static const employeeRead   = 'EMPLOYEES.EMPLOYEE.READ';
  static const employeeCreate = 'EMPLOYEES.EMPLOYEE.CREATE';

  // ─── Department (NEW) ─────────────────────────────────────────────────────
  static const departmentRead   = 'DEPARTMENT.READ';
  static const departmentCreate = 'DEPARTMENT.CREATE';

  // ─── Medical Records ──────────────────────────────────────────────────────
  static const mrRead         = 'MR.PATIENT.READ';
  static const mrCreate       = 'MR.PATIENT.CREATE';
  static const mrUpdate       = 'MR.PATIENT.UPDATE';
  static const mrDelete       = 'MR.PATIENT.DELETE';
  // NEW: MR Data View screen
  static const mrDataViewRead  = 'MR.DATA_VIEW.READ';
  static const mrDataViewPrint = 'MR.DATA_VIEW.PRINT';

  // ─── Lab ──────────────────────────────────────────────────────────────────
  static const labRead   = 'LAB.TEST.READ';
  static const labCreate = 'LAB.TEST.CREATE';
  static const labUpdate = 'LAB.TEST.UPDATE';
  static const labDelete = 'LAB.TEST.DELETE';

  static const labReceiptRead           = 'LAB.RECEIPT.READ';
  static const labTypeRead              = 'LAB.TYPE.READ';
  static const labCategoryRead          = 'LAB.CATEGORY.READ';
  static const labSpecimenRead          = 'LAB.SPECIMEN.READ';
  static const labAttributeRead         = 'LAB.ATTRIBUTE.READ';
  static const labAttributeGroupRead    = 'LAB.ATTRIBUTE_GROUP.READ';
  static const labReportingFormatRead   = 'LAB.REPORTING_FORMAT.READ';

  // ─── Radiology ────────────────────────────────────────────────────────────
  static const radiologyRead   = 'RADIOLOGY.TEST.READ';
  static const radiologyCreate = 'RADIOLOGY.TEST.CREATE';

  // ─── Indoor / Admissions ──────────────────────────────────────────────────
  static const indoorRead   = 'INDOOR.SERVICE.READ';
  static const indoorCreate = 'INDOOR.SERVICE.CREATE';

  // NEW: Admissions module keys (matches React)
  static const admissionsRead       = 'ADMISSIONS.RECORD.READ';
  static const admissionsCreate     = 'ADMISSIONS.RECORD.CREATE';
  static const admissionsUpdate     = 'ADMISSIONS.RECORD.UPDATE';
  static const admissionsCashRead   = 'ADMISSIONS.CASH_RECEIPT.READ';
  static const admissionsCashCreate = 'ADMISSIONS.CASH_RECEIPT.CREATE';

  // ─── Expenses ─────────────────────────────────────────────────────────────
  static const expenseRead   = 'EXPENSES.EXPENSE.READ';
  static const expenseCreate = 'EXPENSES.EXPENSE.CREATE';
  static const expenseUpdate = 'EXPENSES.EXPENSE.UPDATE';
  static const expenseDelete = 'EXPENSES.EXPENSE.DELETE';

  static const expenseHeadRead   = 'EXPENSES.EXPENSE_HEAD.READ';
  static const expenseHeadCreate = 'EXPENSES.EXPENSE_HEAD.CREATE';

  // ─── Emergency ────────────────────────────────────────────────────────────
  static const emergencyRead   = 'EMERGENCY.TREATMENT.READ';
  static const emergencyCreate = 'EMERGENCY.TREATMENT.CREATE';
  static const emergencyUpdate = 'EMERGENCY.TREATMENT.UPDATE';
  static const emergencyDelete = 'EMERGENCY.TREATMENT.DELETE';

  // ─── Consultant Payments ──────────────────────────────────────────────────
  static const consultantRead   = 'CONSULTANT.PAYMENT.READ';
  static const consultantCreate = 'CONSULTANT.PAYMENT.CREATE';
  static const consultantUpdate = 'CONSULTANT.PAYMENT.UPDATE';

  // ─── Prescription (GP) ────────────────────────────────────────────────────
  // FIX: was 'PRESCRIPTION.RECORD.*' — React uses 'PRESCRIPTION.GP_RECORD.*'
  static const prescriptionRead   = 'PRESCRIPTION.GP_RECORD.READ';
  static const prescriptionCreate = 'PRESCRIPTION.GP_RECORD.CREATE';
  static const prescriptionUpdate = 'PRESCRIPTION.GP_RECORD.UPDATE';

  // ─── Prescription (Nutritionist) — NEW ───────────────────────────────────
  static const nutritionistRead   = 'PRESCRIPTION.NUTRITIONIST_RECORD.READ';
  static const nutritionistCreate = 'PRESCRIPTION.NUTRITIONIST_RECORD.CREATE';

  // ─── Prescription (Vitals) — NEW ─────────────────────────────────────────
  static const vitalsRead   = 'PRESCRIPTION.VITALS.READ';
  static const vitalsCreate = 'PRESCRIPTION.VITALS.CREATE';

  // ─── Prescription (Lab Values) — NEW ─────────────────────────────────────
  static const labValuesRead   = 'PRESCRIPTION.LAB_VALUES.READ';
  static const labValuesCreate = 'PRESCRIPTION.LAB_VALUES.CREATE';

  // ─── Prescription (Fundus Examination) — NEW ─────────────────────────────
  static const fundusRead   = 'PRESCRIPTION.FUNDUS_EXAMINATION.READ';
  static const fundusCreate = 'PRESCRIPTION.FUNDUS_EXAMINATION.CREATE';

  // ─── Prescription (Eye) ───────────────────────────────────────────────────
  static const eyeRecordRead        = 'PRESCRIPTION.EYE_RECORD.READ';
  static const eyeRecordUpdate      = 'PRESCRIPTION.EYE_RECORD.UPDATE';
  static const eyeDiagnosisRead     = 'PRESCRIPTION.EYE_DIAGNOSIS.READ';
  static const eyeDiagnosisUpdate   = 'PRESCRIPTION.EYE_DIAGNOSIS.UPDATE';
  static const eyeOptometristRead   = 'PRESCRIPTION.EYE_OPTOMETRIST.READ';
  static const eyeOptometristUpdate = 'PRESCRIPTION.EYE_OPTOMETRIST.UPDATE';
  static const eyeExaminationRead   = 'PRESCRIPTION.EYE_EXAMINATION.READ';
  static const eyeExaminationUpdate = 'PRESCRIPTION.EYE_EXAMINATION.UPDATE';
  static const eyeManagementRead    = 'PRESCRIPTION.EYE_MANAGEMENT.READ';
  static const eyeManagementUpdate  = 'PRESCRIPTION.EYE_MANAGEMENT.UPDATE';
  static const eyeMedicinesRead     = 'PRESCRIPTION.EYE_MEDICINES.READ';
  static const eyeMedicinesUpdate   = 'PRESCRIPTION.EYE_MEDICINES.UPDATE';
  static const eyeHistoryRead       = 'PRESCRIPTION.EYE_HISTORY.READ';

  // ─── Medicines / Pharmacy ─────────────────────────────────────────────────
  static const medicineRead   = 'MEDICINES.MEDICINE.READ';
  static const medicineCreate = 'MEDICINES.MEDICINE.CREATE';
  static const medicineUpdate = 'MEDICINES.MEDICINE.UPDATE';
  static const medicineDelete = 'MEDICINES.MEDICINE.DELETE';

  // ─── Setup ────────────────────────────────────────────────────────────────
  static const setupDiscountTypeRead   = 'SETUP.DISCOUNT_TYPE.READ';
  static const setupDiscountTypeCreate = 'SETUP.DISCOUNT_TYPE.CREATE';
  static const setupDiscountAuthRead   = 'SETUP.DISCOUNT_AUTHORITY.READ';
  static const setupDiscountAuthCreate = 'SETUP.DISCOUNT_AUTHORITY.CREATE';
  static const setupRefFromRead        = 'SETUP.REFERRED_FROM.READ';
  static const setupEyeRead            = 'SETUP.EYE.READ';
  static const setupEyeCreate          = 'SETUP.EYE_SETUP.CREATE';
  static const setupEyeUpdate          = 'SETUP.EYE_SETUP.UPDATE';

  // ─── Diagnosis ────────────────────────────────────────────────────────────
  static const diagnosisDeptRead     = 'DIAGNOSIS.DEPARTMENT.READ';
  static const diagnosisTypeRead     = 'DIAGNOSIS.TYPE.READ';
  static const diagnosisQuestionRead = 'DIAGNOSIS.QUESTION.READ';

  // ─── Company Settings ─────────────────────────────────────────────────────
  static const companyRead   = 'COMPANY.SETTINGS.READ';
  static const companyUpdate = 'COMPANY.SETTINGS.UPDATE';

  // ─── Access Control ───────────────────────────────────────────────────────
  static const accessGroupsRead       = 'ACCESS.GROUPS.READ';
  static const accessGroupsCreate     = 'ACCESS.GROUPS.CREATE';
  static const accessGroupsUpdate     = 'ACCESS.GROUPS.UPDATE';
  static const accessGroupsDelete     = 'ACCESS.GROUPS.DELETE';
  static const accessPermsRead        = 'ACCESS.PERMISSIONS.READ';
  static const accessUserGroupsRead   = 'ACCESS.USER_GROUPS.READ';
  static const accessUserGroupsUpdate = 'ACCESS.USER_GROUPS.UPDATE';
  static const accessIpRead           = 'ACCESS.IP.READ';

  // ─── Profile ──────────────────────────────────────────────────────────────
  static const profilePasswordUpdate = 'PROFILE.PASSWORD.UPDATE';

  // ─── Complaints Board (NEW) ───────────────────────────────────────────────
  static const complaintsBoardRead = 'COMPLAINTS.BOARD.READ';

  // ─── Camps ────────────────────────────────────────────────────────────────
  static const campDashboardRead   = 'CAMPS.DASHBOARD.READ';
  static const campDashboardDelete = 'CAMPS.DASHBOARD.DELETE';
  static const campSessionCreate   = 'CAMPS.SESSION.CREATE';
  static const campSessionUpdate   = 'CAMPS.SESSION.UPDATE';

  /// Super Admin wildcard — matches everything
  static const wildcard = '*';
}
