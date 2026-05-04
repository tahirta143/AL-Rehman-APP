import 'package:flutter/material.dart';
import 'package:hims_app/core/providers/permission_provider.dart';
import 'package:hims_app/providers/dashboard/dashboard_provider.dart';
import 'package:hims_app/providers/emergency_treatment_provider/emergency_provider.dart';
import 'package:hims_app/providers/mr_provider/mr_provider.dart';
import 'package:hims_app/providers/opd/consultation_provider/cunsultation_provider.dart';
import 'package:hims_app/providers/opd/opd_reciepts/opd_reciepts.dart';
import 'package:hims_app/providers/prescription_provider/lab_values_provider.dart';
import 'package:hims_app/providers/shift_management/shift_management.dart';
import 'package:hims_app/providers/consultant_payments_provider/consultant_payments_provider.dart';
import 'package:hims_app/providers/vitals_provider/vitals_provider.dart';
import 'package:hims_app/providers/voucher_provider/voucher.dart';
import 'package:hims_app/providers/ai_chat/ai_chat_provider.dart';
import 'package:hims_app/providers/dashboard/offline_dashboard_provider.dart';
import 'package:hims_app/screens/dashboard/offline_dashboard.dart';
import 'package:hims_app/screens/splash%20screens/splash.dart';
import 'package:hims_app/providers/mobile_auth_provider.dart';
import 'package:hims_app/providers/appointments_provider/appointments_provider.dart';
import 'package:hims_app/providers/prescription_provider/prescription_provider.dart';
import 'package:hims_app/providers/nutrition_provider/nutrition_provider.dart';
import 'package:hims_app/providers/eye_provider/fundus_provider.dart';
import 'package:hims_app/providers/pharmacy_provider/pharmacy_provider.dart';
import 'package:hims_app/providers/sync_provider.dart';
import 'package:hims_app/screens/main_shell.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// In your main.dart or a separate file
final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
final GlobalKey<ScaffoldMessengerState> snackbarKey = GlobalKey<ScaffoldMessengerState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ─── RBAC ─────────────────────────────────────────────────────
        ChangeNotifierProvider(create: (_) => PermissionProvider()),

        // ─── Existing Providers ───────────────────────────────────────
        ChangeNotifierProvider(create: (_) => ConsultationProvider()),
        ChangeNotifierProvider(create: (_) => OpdProvider()),
        ChangeNotifierProvider(create: (_) => EmergencyProvider()),
        ChangeNotifierProvider(create: (_) => MrProvider()),
        ChangeNotifierProvider(create: (_) => ShiftProvider()),
        ChangeNotifierProvider(create: (_) => VoucherProvider()),
        ChangeNotifierProvider(create: (_) => ConsultantPaymentsProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => AiChatProvider()),
        ChangeNotifierProvider(create: (_) => MobileAuthProvider()),
        ChangeNotifierProvider(create: (_) => AppointmentsProvider()),
        ChangeNotifierProvider(create: (_) => PrescriptionProvider()),
        ChangeNotifierProvider(create: (_) => VitalsProvider()),
        ChangeNotifierProvider(create: (_) => LabValuesProvider()),
        ChangeNotifierProvider(create: (_) => NutritionProvider()),
        ChangeNotifierProvider(create: (_) => FundusProvider()),
        ChangeNotifierProvider(create: (_) => PharmacyProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => OfflineDashboardProvider()),
      ],
      child: MaterialApp(
        title: 'Waseela Diabesity',
        scaffoldMessengerKey: snackbarKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1ABC9C)),
          useMaterial3: true,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
              TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(),
              TargetPlatform.windows: FadeThroughPageTransitionsBuilder(),
              TargetPlatform.macOS: FadeThroughPageTransitionsBuilder(),
              TargetPlatform.linux: FadeThroughPageTransitionsBuilder(),
            },
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
