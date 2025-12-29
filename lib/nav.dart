import 'package:go_router/go_router.dart';
import 'package:bimmerwise_connect/pages/home_page.dart';
import 'package:bimmerwise_connect/pages/customers_page.dart';
import 'package:bimmerwise_connect/pages/customer_profile_page.dart';
import 'package:bimmerwise_connect/pages/booking_page.dart';
import 'package:bimmerwise_connect/pages/service_selection_page.dart';
import 'package:bimmerwise_connect/pages/auth_selection_page.dart';
import 'package:bimmerwise_connect/pages/login_page.dart';
import 'package:bimmerwise_connect/pages/guest_booking_page.dart';
import 'package:bimmerwise_connect/pages/registered_booking_page.dart';
import 'package:bimmerwise_connect/pages/register_page.dart';
import 'package:bimmerwise_connect/pages/user_profile_page.dart';
import 'package:bimmerwise_connect/pages/admin_login_page.dart';
import 'package:bimmerwise_connect/pages/admin_panel_page.dart';
import 'package:bimmerwise_connect/pages/carplay_booking_page.dart';
import 'package:bimmerwise_connect/pages/gearbox_booking_page.dart';
import 'package:bimmerwise_connect/pages/regular_service_booking_page.dart';
import 'package:bimmerwise_connect/pages/privacy_policy_page.dart';
import 'package:bimmerwise_connect/pages/terms_of_service_page.dart';
import 'package:bimmerwise_connect/pages/products_page.dart';
import 'package:bimmerwise_connect/pages/product_detail_page.dart';
import 'package:bimmerwise_connect/pages/cart_page.dart';
import 'package:bimmerwise_connect/pages/checkout_page.dart';
import 'package:bimmerwise_connect/pages/admin_products_page.dart';
import 'package:bimmerwise_connect/pages/xhp_remap_booking_page.dart';

/// GoRouter configuration for app navigation
///
/// This uses go_router for declarative routing, which provides:
/// - Type-safe navigation
/// - Deep linking support (web URLs, app links)
/// - Easy route parameters
/// - Navigation guards and redirects
///
/// To add a new route:
/// 1. Add a route constant to AppRoutes below
/// 2. Add a GoRoute to the routes list
/// 3. Navigate using context.go() or context.push()
/// 4. Use context.pop() to go back.
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const HomePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.customers,
        name: 'customers',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const CustomersPage(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.customer}/:id',
        name: 'customer',
        pageBuilder: (context, state) {
          final customerId = state.pathParameters['id']!;
          final highlightBookingId = state.uri.queryParameters['highlightBookingId'];
          return NoTransitionPage(
            child: CustomerProfilePage(
              customerId: customerId,
              highlightBookingId: highlightBookingId,
            ),
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.booking}/:id',
        name: 'booking',
        pageBuilder: (context, state) {
          final customerId = state.pathParameters['id']!;
          return NoTransitionPage(
            child: BookingPage(customerId: customerId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.serviceSelection,
        name: 'serviceSelection',
        pageBuilder: (context, state) {
          final category = state.uri.queryParameters['category'] ?? 'bookin';
          return NoTransitionPage(
            child: ServiceSelectionPage(category: category),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.authSelection,
        name: 'authSelection',
        pageBuilder: (context, state) {
          final serviceTitle = state.uri.queryParameters['service'] ?? '';
          final serviceCategory = state.uri.queryParameters['category'] ?? '';
          return NoTransitionPage(
            child: AuthSelectionPage(
              serviceTitle: serviceTitle,
              serviceCategory: serviceCategory,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) {
          final serviceTitle = state.uri.queryParameters['service'] ?? '';
          final serviceCategory = state.uri.queryParameters['category'] ?? '';
          return NoTransitionPage(
            child: LoginPage(
              serviceTitle: serviceTitle,
              serviceCategory: serviceCategory,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.guestBooking,
        name: 'guestBooking',
        pageBuilder: (context, state) {
          final serviceTitle = state.uri.queryParameters['service'] ?? '';
          final serviceCategory = state.uri.queryParameters['category'] ?? '';
          return NoTransitionPage(
            child: GuestBookingPage(
              serviceTitle: serviceTitle,
              serviceCategory: serviceCategory,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.registeredBooking,
        name: 'registeredBooking',
        pageBuilder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          final serviceTitle = state.uri.queryParameters['service'] ?? '';
          final serviceCategory = state.uri.queryParameters['category'] ?? '';
          return NoTransitionPage(
            child: RegisteredBookingPage(
              userId: userId,
              serviceTitle: serviceTitle,
              serviceCategory: serviceCategory,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: RegisterPage(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.userProfile}/:userId',
        name: 'userProfile',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final scrollTo = state.uri.queryParameters['scrollTo'];
          return NoTransitionPage(
            child: UserProfilePage(userId: userId, scrollTo: scrollTo),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.adminLogin,
        name: 'adminLogin',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: AdminLoginPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminPanel,
        name: 'adminPanel',
        pageBuilder: (context, state) {
          final highlightBookingId = state.uri.queryParameters['highlightBookingId'];
          return NoTransitionPage(
            child: AdminPanelPage(highlightBookingId: highlightBookingId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.carplayBooking,
        name: 'carplayBooking',
        pageBuilder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          return NoTransitionPage(
            child: CarplayBookingPage(userId: userId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.gearboxBooking,
        name: 'gearboxBooking',
        pageBuilder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          return NoTransitionPage(
            child: GearboxBookingPage(userId: userId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.regularServiceBooking,
        name: 'regularServiceBooking',
        pageBuilder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          return NoTransitionPage(
            child: RegularServiceBookingPage(userId: userId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.xhpRemapBooking,
        name: 'xhpRemapBooking',
        pageBuilder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          return NoTransitionPage(
            child: XhpRemapBookingPage(userId: userId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        name: 'privacyPolicy',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: PrivacyPolicyPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.termsOfService,
        name: 'termsOfService',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: TermsOfServicePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.products,
        name: 'products',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ProductsPage(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.product}/:id',
        name: 'product',
        pageBuilder: (context, state) {
          final productId = state.pathParameters['id']!;
          return NoTransitionPage(
            child: ProductDetailPage(productId: productId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.cart,
        name: 'cart',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: CartPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        name: 'checkout',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: CheckoutPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminProducts,
        name: 'adminProducts',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: AdminProductsPage(),
        ),
      ),
    ],
  );
}

/// Route path constants
/// Use these instead of hard-coding route strings
class AppRoutes {
  static const String home = '/';
  static const String customers = '/customers';
  static const String customer = '/customer';
  static const String booking = '/booking';
  static const String serviceSelection = '/service-selection';
  static const String authSelection = '/auth-selection';
  static const String login = '/login';
  static const String guestBooking = '/guest-booking';
  static const String registeredBooking = '/registered-booking';
  static const String register = '/register';
  static const String userProfile = '/user-profile';
  static const String adminLogin = '/admin-login';
  static const String adminPanel = '/admin-panel';
  static const String carplayBooking = '/carplay-booking';
  static const String gearboxBooking = '/gearbox-booking';
  static const String regularServiceBooking = '/regular-service-booking';
  static const String xhpRemapBooking = '/xhp-remap-booking';
  static const String privacyPolicy = '/privacy-policy';
  static const String termsOfService = '/terms-of-service';
  static const String products = '/products';
  static const String product = '/product';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String adminProducts = '/admin-products';
}
