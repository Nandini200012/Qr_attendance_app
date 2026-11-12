import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_attendance_app/core/constants/app_constants.dart';
import 'package:qr_attendance_app/core/di/injection_container.dart';
import 'package:qr_attendance_app/core/router/app_router.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_event.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_state.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/bloc/qr_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(const SmartQrAttendanceApp());
}

class SmartQrAttendanceApp extends StatefulWidget {
  const SmartQrAttendanceApp({super.key});

  @override
  State<SmartQrAttendanceApp> createState() => _SmartQrAttendanceAppState();
}

class _SmartQrAttendanceAppState extends State<SmartQrAttendanceApp> {
  late final AuthBloc _authBloc;
  late final AppRouter _appRouter;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _authBloc = sl<AuthBloc>()..add(const AuthCheckRequested());
    _appRouter = AppRouter(_authBloc);
  }

  @override
  void dispose() {
    _appRouter.dispose();
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _authBloc),
        BlocProvider<AttendanceBloc>(create: (_) => sl<AttendanceBloc>()),
        BlocProvider<QRBloc>(create: (_) => sl<QRBloc>()),
        BlocProvider<AdminBloc>(create: (_) => sl<AdminBloc>()),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            current.infoMessage != null &&
            current.infoMessage != previous.infoMessage,
        listener: (_, state) {
          final msg = state.infoMessage;
          if (msg == null) return;
          _scaffoldMessengerKey.currentState
            ?..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(msg)),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
        },
        child: MaterialApp.router(
          scaffoldMessengerKey: _scaffoldMessengerKey,
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: _appRouter.router,
        ),
      ),
    );
  }
}
