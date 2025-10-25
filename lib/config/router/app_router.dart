import 'package:go_router/go_router.dart';
import 'package:sioma_biometrics/presentation/screens/attendances/attendances_screen.dart';
import 'package:sioma_biometrics/presentation/screens/home_screen.dart';
import 'package:sioma_biometrics/presentation/screens/register_screen/register_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: "/",
  routes: [
    GoRoute(path: "/", builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: "/register",
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: "/attendances",
      builder: (context, state) => const Attendances(),
    ),
  ],
);
