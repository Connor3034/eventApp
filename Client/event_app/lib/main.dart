import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'events_service.dart';
import 'pages/login.dart';
import 'pages/main_shell.dart';

void main() {
  final authService = AuthService();
  runApp(
    MyApp(
      authService: authService,
      eventsService: EventsService(authService),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({
    required this.authService,
    required this.eventsService,
    super.key,
  });

  final AuthService authService;
  final EventsService eventsService;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    widget.authService.addListener(_handleAuthChanged);
    widget.authService.initialize();
  }

  @override
  void dispose() {
    widget.authService.removeListener(_handleAuthChanged);
    widget.authService.dispose();
    widget.eventsService.dispose();
    super.dispose();
  }

  void _handleAuthChanged() {
    if (!widget.authService.isAuthenticated) {
      widget.eventsService.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Event planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 97, 55, 170),
        ),
        useMaterial3: true,
      ),
      home: AnimatedBuilder(
        animation: widget.authService,
        builder: (context, child) {
          if (widget.authService.isInitializing) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (widget.authService.isAuthenticated) {
            return MainShell(
              authService: widget.authService,
              eventsService: widget.eventsService,
            );
          }
          return Login(authService: widget.authService);
        },
      ),
    );
  }
}
