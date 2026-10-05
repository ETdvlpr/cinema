import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/repository.dart';
import 'state/schedule_controller.dart';
import 'state/schedule_scope.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
    ),
  );
  runApp(CinemaApp(controller: ScheduleController(ScheduleRepository())..load()));
}

class CinemaApp extends StatefulWidget {
  const CinemaApp({super.key, required this.controller});

  final ScheduleController controller;

  @override
  State<CinemaApp> createState() => _CinemaAppState();
}

class _CinemaAppState extends State<CinemaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back to the app later in the day: fetch the latest and drop showtimes that have passed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ScheduleScope(
      controller: widget.controller,
      child: MaterialApp(
        title: 'Addis Cinema',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // Phone-shaped column on tablets and desktop browsers.
        builder: (context, child) => ColoredBox(
          color: AppColors.background,
          child: Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: child),
          ),
        ),
        home: const HomeShell(),
      ),
    );
  }
}
