import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'pages/home_page.dart';
import 'pages/login.dart';

void main() {
  runApp(MyApp(authService: AuthService()));
}

class MyApp extends StatefulWidget {
  const MyApp({required this.authService, super.key});

  final AuthService authService;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    widget.authService.initialize();
  }

  @override
  void dispose() {
    widget.authService.dispose();
    super.dispose();
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
            return HomePage(authService: widget.authService);
          }
          return Login(authService: widget.authService);
        },
      ),
    );
  }
}
    