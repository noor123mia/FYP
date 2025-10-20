import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/screens/AllCandidates.dart';
import 'package:flutter_application_2/screens/AppliedCandidatesMatchingScreen.dart';
import 'package:flutter_application_2/screens/CandidateApplicationScreen.dart';
import 'package:flutter_application_2/screens/CandidateMatchDetailScreen.dart';
import 'package:flutter_application_2/screens/CandidateOffers.dart';
import 'package:flutter_application_2/screens/InterviewManagementScreen.dart';
import 'package:flutter_application_2/screens/InterviewScheduleScreen.dart';
import 'package:flutter_application_2/screens/JobsAppliedByCandidatesScreen.dart';
import 'package:flutter_application_2/screens/DraftJobsScreen.dart';
import 'package:flutter_application_2/screens/In_App_Chat_Screen.dart';
import 'package:flutter_application_2/screens/InterviewQuestionsScreen.dart';
import 'package:flutter_application_2/screens/OfferLetterAutomationScreen.dart';
import 'package:flutter_application_2/screens/PostedJobsScreen.dart';
import 'package:flutter_application_2/screens/notifications_screen.dart';
import 'package:flutter_application_2/services/AppNotificationManager.dart';
import 'package:flutter_application_2/services/fcm_token_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_application_2/services/supabase_config.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
//import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Initialize Firebase in the background isolate
    await Firebase.initializeApp();
    print('Handling a background message: ${message.messageId}');

    // You can process the message here, e.g., save it to local storage
    if (message.notification != null) {
      print('Background message title: ${message.notification!.title}');
      print('Background message body: ${message.notification!.body}');
    }

    // Note: You cannot show UI directly in the background handler.
    // If you want to show a notification, you can use flutter_local_notifications
    // by setting up a separate isolate, but it's simpler to handle this in the foreground handler.
  } catch (e) {
    print('Error handling background message: $e');
  }
}

// Initialize the FlutterLocalNotificationsPlugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Android notification channel
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'job_matches', // id
  'Job Matches', // title
  description: 'Notifications for new job matches',
  importance: Importance.high,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notifications for Android
  try {
    final androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
    }
  } catch (e) {
    print('Error creating notification channel: $e');
  }

  // Initialize notification settings
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  // Initialize flutter_local_notifications
  try {
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap (e.g., navigate to a specific screen)
        print('Notification tapped: ${response.payload}');
      },
    );
  } catch (e) {
    print('Error initializing local notifications: $e');
  }

  // Set foreground notification presentation options
  try {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (e) {
    print('Error setting foreground notification options: $e');
  }

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Received foreground message: ${message.messageId}');
    if (message.notification != null) {
      print('Foreground message title: ${message.notification!.title}');
      print('Foreground message body: ${message.notification!.body}');

      // Show a local notification for foreground messages
      flutterLocalNotificationsPlugin.show(
        message.hashCode,
        message.notification!.title,
        message.notification!.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    }
  });

  // Handle notification taps when the app is opened from a terminated state
  final RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    print(
        'App opened from terminated state with message: ${initialMessage.messageId}');
    // Handle the initial message (e.g., navigate to a specific screen)
  }

  // Handle notification taps when the app is in the background and opened
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('App opened from background with message: ${message.messageId}');
    // Handle the message (e.g., navigate to a specific screen)
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => FCMTokenProvider()),
        // Other providers...
      ],
      child: MyApp(),
    ),
  );
}

class UserProvider extends ChangeNotifier {
  firebase_auth.User? _user;
  Map<String, dynamic>? _userData;
  bool _isRecruiter = false;
  bool _isDarkMode = false;
  bool _isLoading = false;
  String _preferredLanguage = 'English';
  bool _enableNotifications = true;

  firebase_auth.User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  bool get isRecruiter => _isRecruiter;
  bool get isDarkMode => _isDarkMode;
  bool get isLoading => _isLoading;
  String get preferredLanguage => _preferredLanguage;
  bool get enableNotifications => _enableNotifications;

  void setUser(firebase_auth.User? user) {
    _user = user;
    notifyListeners();
  }

  void setUserData(Map<String, dynamic>? userData) {
    _userData = userData;
    _isRecruiter = userData?['userType'] == 'recruiter';
    notifyListeners();
  }

  void signOut() {
    _user = null;
    _userData = null;
    _isRecruiter = false;
    notifyListeners();
  }

  void setIsLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setPreferredLanguage(String language) {
    _preferredLanguage = language;
    notifyListeners();
  }

  void toggleNotifications() {
    _enableNotifications = !_enableNotifications;
    notifyListeners();
  }
}

// Global variable to track "Don't show again" preference
class GlobalPreferences {
  static bool dontShowResumeUploadScreen = false;
}

final appTheme = ThemeData(
  primaryColor: Color(0xFF1E3A8A), // Rich navy blue
  primaryColorLight: Color(0xFF3151A6),
  secondaryHeaderColor: Color(0xFF0D9488), // Teal accent
  scaffoldBackgroundColor: Color(0xFFF9FAFB),
  fontFamily:
      'Poppins', // Assuming Poppins is available, otherwise system font will be used
  textTheme: TextTheme(
    headlineLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1F2937),
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1F2937),
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1F2937),
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1F2937),
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      color: Color(0xFF1F2937),
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: Color(0xFF6B7280),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    ),
  ),
  cardTheme: CardTheme(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    elevation: 2,
    color: Colors.white,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF1E3A8A),
    elevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: Colors.white),
    toolbarTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
  colorScheme: ColorScheme.light(
    primary: Color(0xFF1E3A8A),
    secondary: Color(0xFF0D9488),
    surface: Colors.white,
    background: Color(0xFFF9FAFB),
    error: Color(0xFFEF4444),
  ),
);

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return MaterialApp(
      title: 'SmartRecruit',
      theme: appTheme,
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Color(0xFF1E3A8A),
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF1E3A8A),
          secondary: Color(0xFF0D9488),
        ),
      ),
      themeMode: userProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      //home: userProvider.isLoading
      // ? LoadingScreen()
      //: (userProvider.userData != null ? HomeScreen() : AuthWrapper()),

      // Set up routing
      initialRoute: '/',
      routes: {
        '/': (context) => userProvider.isLoading
            ? LoadingScreen()
            : (userProvider.userData != null ? HomeScreen() : AuthWrapper()),
        '/DraftJobsScreen': (context) => DraftJobsScreen(),
        '/HomeScreen': (context) => HomeScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final firebase_auth.User? user = snapshot.data as firebase_auth.User?;

          if (user == null) {
            userProvider.setUser(null);
            return WelcomeScreen();
          } else {
            userProvider.setUser(user);

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.done) {
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final data =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    userProvider.setUserData(data);

                    final userData = userProvider.userData;

                    // Redirect based on userType
                    if (userData?['userType'] == 'recruiter') {
                      if (userData?['isVerified'] == false) {
                        return VerificationScreen();
                      } else {
                        return HomeScreen();
                      }
                    } else if (userData?['userType'] == 'jobseeker') {
                      if (GlobalPreferences.dontShowResumeUploadScreen ==
                          false) {
                        return ResumeUploadScreen();
                      } else {
                        return HomeScreen();
                      }
                    } else {
                      return HomeScreen();
                    }
                  }
                }
                return LoadingScreen();
              },
            );
          }
        }
        return LoadingScreen();
      },
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get screen height to make layout responsive
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFE2E8F0),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Use Expanded with flex to distribute space proportionally
                Expanded(
                  flex: 2,
                  child: FadeInDown(
                    duration: Duration(milliseconds: 800),
                    child: _buildLogo(),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: FadeInUp(
                    duration: Duration(milliseconds: 1000),
                    delay: Duration(milliseconds: 300),
                    child: _buildWelcomeIllustration(),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: FadeInUp(
                    duration: Duration(milliseconds: 1000),
                    delay: Duration(milliseconds: 500),
                    child: _buildWelcomeText(),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeInUp(
                        duration: Duration(milliseconds: 1000),
                        delay: Duration(milliseconds: 700),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        LoginScreen(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  var begin = Offset(0.0, 0.2);
                                  var end = Offset.zero;
                                  var curve = Curves.easeOutQuint;
                                  var tween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));
                                  var offsetAnimation = animation.drive(tween);
                                  return SlideTransition(
                                      position: offsetAnimation, child: child);
                                },
                                transitionDuration: Duration(milliseconds: 600),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                          ),
                          child: Text('Sign In'),
                        ),
                      ),
                      SizedBox(height: 12),
                      FadeInUp(
                        duration: Duration(milliseconds: 1000),
                        delay: Duration(milliseconds: 800),
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        RegisterScreen(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  var begin = Offset(0.0, 0.2);
                                  var end = Offset.zero;
                                  var curve = Curves.easeOutQuint;
                                  var tween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));
                                  var offsetAnimation = animation.drive(tween);
                                  return SlideTransition(
                                      position: offsetAnimation, child: child);
                                },
                                transitionDuration: Duration(milliseconds: 600),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                          ),
                          child: Text('Create Account'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF1E3A8A).withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.work_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds);
            },
            child: Text(
              'SmartRecruit',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeIllustration() {
    return Container(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.network(
                'https://img.freepik.com/free-vector/business-team-discussing-ideas-startup_74855-4380.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF1E3A8A),
                          Color(0xFF0D9488),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.business_center_rounded,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Discover Your Next Career Move',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            height: 1.2,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Connect with top companies and find your perfect job match with our AI-powered recruiting platform',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await firebase_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      Navigator.of(context).pop();
    } on firebase_auth.FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = 'No user found with this email.';
        } else if (e.code == 'wrong-password') {
          _errorMessage = 'Incorrect password.';
        } else {
          _errorMessage = 'Login failed: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF1E3A8A)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeInDown(
                    duration: Duration(milliseconds: 600),
                    child: Container(
                      alignment: Alignment.center,
                      child: Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF1E3A8A).withOpacity(0.3),
                              blurRadius: 15,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.login_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  FadeInDown(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 200),
                    child: Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  FadeInDown(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 300),
                    child: Text(
                      'Sign in to your account to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  SizedBox(height: 40),
                  if (_errorMessage.isNotEmpty) ...[
                    FadeIn(
                      duration: Duration(milliseconds: 400),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(color: Color(0xFFB91C1C)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 400),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: Icon(Icons.email_outlined,
                              color: Color(0xFF1E3A8A)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 500),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: Icon(Icons.lock_outline,
                              color: Color(0xFF1E3A8A)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Color(0xFF64748B),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 600),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ForgotPasswordScreen()),
                          );
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color(0xFF0D9488),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 700),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1E3A8A),
                        padding: EdgeInsets.symmetric(vertical: 18),
                        elevation: 4,
                        shadowColor: Color(0xFF1E3A8A).withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text('Sign In',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5)),
                    ),
                  ),
                  SizedBox(height: 32),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 800),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => RegisterScreen()),
                            );
                          },
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Color(0xFF0D9488),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String _errorMessage = '';

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await firebase_auth.FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      setState(() {
        _emailSent = true;
      });
    } on firebase_auth.FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = 'No user found with this email.';
        } else {
          _errorMessage = 'Error: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF1E3A8A)),
        title: Text(
          'Forgot Password',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: _emailSent ? _buildSuccessView() : _buildFormView(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return FadeIn(
      duration: Duration(milliseconds: 500),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Color(0xFFD1FAE5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Color(0xFF0D9488),
            ),
          ),
          SizedBox(height: 32),
          Text(
            'Password Reset Email Sent',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            'We\'ve sent a password reset link to:',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            _emailController.text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D9488),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Text(
            'Please check your email and follow the instructions to reset your password.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1E3A8A),
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 40),
              elevation: 4,
              shadowColor: Color(0xFF1E3A8A).withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Back to Login',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeInDown(
            duration: Duration(milliseconds: 600),
            child: Container(
              alignment: Alignment.center,
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF1E3A8A).withOpacity(0.3),
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.lock_reset_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
          SizedBox(height: 30),
          FadeInDown(
            duration: Duration(milliseconds: 600),
            delay: Duration(milliseconds: 200),
            child: Text(
              'Forgot Your Password?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(height: 16),
          FadeInDown(
            duration: Duration(milliseconds: 600),
            delay: Duration(milliseconds: 300),
            child: Text(
              'Enter your email address and we\'ll send you a link to reset your password',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
                height: 1.5,
                letterSpacing: 0.3,
              ),
            ),
          ),
          SizedBox(height: 40),
          if (_errorMessage.isNotEmpty) ...[
            FadeIn(
              duration: Duration(milliseconds: 400),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Color(0xFFB91C1C)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
          FadeInUp(
            duration: Duration(milliseconds: 600),
            delay: Duration(milliseconds: 400),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Color(0xFF64748B)),
                  prefixIcon:
                      Icon(Icons.email_outlined, color: Color(0xFF1E3A8A)),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
            ),
          ),
          SizedBox(height: 32),
          FadeInUp(
            duration: Duration(milliseconds: 600),
            delay: Duration(milliseconds: 500),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _resetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1E3A8A),
                padding: EdgeInsets.symmetric(vertical: 18),
                elevation: 4,
                shadowColor: Color(0xFF1E3A8A).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text('Reset Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      )),
            ),
          ),
          SizedBox(height: 24),
          FadeInUp(
            duration: Duration(milliseconds: 600),
            delay: Duration(milliseconds: 600),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Remember your password? ",
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                      color: Color(0xFF0D9488),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _errorMessage = '';
  String _userType = 'jobseeker';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      firebase_auth.UserCredential userCredential = await firebase_auth
          .FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Create initial user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'email': _emailController.text.trim(),
        'userType': _userType,
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': _userType == 'recruiter' ? false : true,
      });

      // Navigate back to auth wrapper which will handle the routing
      Navigator.of(context).pop();
    } on firebase_auth.FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'weak-password') {
          _errorMessage = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          _errorMessage = 'An account already exists for this email.';
        } else {
          _errorMessage = 'Registration failed: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fixed sizes instead of percentage-based ones
    const double iconSize = 23.0;
    const double headerFontSize = 24.0;
    const double subtitleFontSize = 16.0;
    const double bodyFontSize = 16.0;
    const double verticalSpacing = 20.0;
    const double formPadding = 16.0;

    return Scaffold(
      backgroundColor: Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF1E3A8A)),
        toolbarHeight: 56.0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // Header Section
                  Container(
                    height: 130,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FadeInDown(
                          duration: Duration(milliseconds: 600),
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF1E3A8A).withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.person_add_rounded,
                              color: Colors.white,
                              size: 27,
                            ),
                          ),
                        ),
                        SizedBox(height: 11),
                        FadeInDown(
                          duration: Duration(milliseconds: 600),
                          delay: Duration(milliseconds: 200),
                          child: Text(
                            'Create Account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: headerFontSize,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        FadeInDown(
                          duration: Duration(milliseconds: 600),
                          delay: Duration(milliseconds: 300),
                          child: Text(
                            'Sign up to get started with SmartRecruit',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: subtitleFontSize,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // User Type Selection
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 350),
                    child: Container(
                      margin: EdgeInsets.only(top: 12, bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 7, horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'I am a:',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                                fontSize: bodyFontSize,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text('Job Seeker',
                                        style:
                                            TextStyle(fontSize: bodyFontSize)),
                                    value: 'jobseeker',
                                    groupValue: _userType,
                                    onChanged: (value) {
                                      setState(() {
                                        _userType = value!;
                                      });
                                    },
                                    activeColor: Color(0xFF0D9488),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text('Recruiter',
                                        style:
                                            TextStyle(fontSize: bodyFontSize)),
                                    value: 'recruiter',
                                    groupValue: _userType,
                                    onChanged: (value) {
                                      setState(() {
                                        _userType = value!;
                                      });
                                    },
                                    activeColor: Color(0xFF0D9488),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Error Message
                  if (_errorMessage.isNotEmpty) ...[
                    FadeIn(
                      duration: Duration(milliseconds: 400),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Color(0xFFB91C1C), size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: bodyFontSize,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Email Field
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 400),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: bodyFontSize,
                          ),
                          prefixIcon: Icon(Icons.email_outlined,
                              color: Color(0xFF1E3A8A), size: 22),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(fontSize: bodyFontSize),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                  // Password Field
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 500),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: bodyFontSize,
                          ),
                          prefixIcon: Icon(Icons.lock_outline,
                              color: Color(0xFF1E3A8A), size: 22),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Color(0xFF64748B),
                              size: 22,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        obscureText: _obscurePassword,
                        style: TextStyle(fontSize: bodyFontSize),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                  // Confirm Password Field
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 600),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          labelStyle: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: bodyFontSize,
                          ),
                          prefixIcon: Icon(Icons.lock_outline,
                              color: Color(0xFF1E3A8A), size: 22),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Color(0xFF64748B),
                              size: 22,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        obscureText: _obscureConfirmPassword,
                        style: TextStyle(fontSize: bodyFontSize),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                  // Create Account Button
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 700),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      margin: EdgeInsets.only(bottom: 15),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: Color(0xFF1E3A8A).withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 23,
                                width: 23,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text('Create Account',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                )),
                      ),
                    ),
                  ),

                  // Sign In Link
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 800),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 16,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => LoginScreen()),
                              );
                            },
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: Color(0xFF0D9488),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VerificationScreen extends StatefulWidget {
  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _companyWebsiteController = TextEditingController();
  final _businessIdController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyWebsiteController.dispose();
    _businessIdController.dispose();
    super.dispose();
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('verificationRequests').add({
        'userId': user!.uid,
        'companyName': _companyNameController.text.trim(),
        'companyWebsite': _companyWebsiteController.text.trim(),
        'businessId': _businessIdController.text.trim(),
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'verificationRequestSubmitted': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification request submitted successfully!'),
          backgroundColor: Color(0xFF0D9488), // Teal
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting verification: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF1F5F9), // Lighter background
      appBar: AppBar(
        title: Text(
          'Recruiter Verification',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF1E3A8A), // Navy blue
        automaticallyImplyLeading: false,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeInDown(
                    duration: Duration(milliseconds: 600),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFE0F2F1), // Light teal background
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Color(0xFF0D9488)), // Teal
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your account requires verification to post jobs. Please provide your business details.',
                              style: TextStyle(
                                  color: Color(0xFF0D9488),
                                  fontWeight: FontWeight.w500), // Teal
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  FadeInDown(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 200),
                    child: Text(
                      'Business Verification',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A), // Navy blue
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  FadeInDown(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 300),
                    child: Text(
                      'Please provide your business information for verification',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF64748B), // Lighter text for subtitle
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 400),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _companyNameController,
                        decoration: InputDecoration(
                          labelText: 'Company Name',
                          labelStyle: TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: Icon(Icons.business_outlined,
                              color: Color(0xFF1E3A8A)), // Navy
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your company name';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 500),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _companyWebsiteController,
                        decoration: InputDecoration(
                          labelText: 'Company Website',
                          labelStyle: TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: Icon(Icons.language_outlined,
                              color: Color(0xFF1E3A8A)), // Navy
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        keyboardType: TextInputType.url,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your company website';
                          }
                          if (!value.startsWith('http://') &&
                              !value.startsWith('https://')) {
                            return 'Website must start with http:// or https://';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 600),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _businessIdController,
                        decoration: InputDecoration(
                          labelText: 'Business ID / Registration Number',
                          labelStyle: TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: Icon(Icons.badge_outlined,
                              color: Color(0xFF1E3A8A)), // Navy
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your business ID';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 700),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1E3A8A), // Navy blue
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 18),
                        elevation: 4,
                        shadowColor: Color(0xFF1E3A8A).withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16), // More rounded corners
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text('Submit Verification',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(height: 16),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 800),
                    child: TextButton(
                      onPressed: () async {
                        await firebase_auth.FirebaseAuth.instance.signOut();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Color(0xFF64748B),
                      ),
                      child: Text('Logout and Return Later'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<Feature> _primaryFeatures = [];
  final List<Feature> _secondaryFeatures = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _animationController.forward();

    // Initialize features after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFeatures();
    });
  }

  /*Future<void> _openCandidatesMatching(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      // PEHLE: Applied candidates fetch karo (all candidates)
      final candidatesSnapshot = await FirebaseFirestore.instance
          .collection('AppliedCandidates')
          .get();

      if (candidatesSnapshot.docs.isEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No applied candidates found in database')),
        );
        return;
      }

      // PHIR: Check karo kis job par candidates hain
      // Pehle candidate ka jobId lo
      final firstCandidateJobId = candidatesSnapshot.docs.first.data()['jobId'];

      if (firstCandidateJobId == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Candidate data incomplete - missing jobId')),
        );
        return;
      }

      // AB: Us specific job ka data fetch karo
      final jobDoc = await FirebaseFirestore.instance
          .collection('JobsPosted')
          .doc(firstCandidateJobId)
          .get();

      if (!jobDoc.exists) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Job not found for applied candidates')),
        );
        return;
      }

      // JOB DATA KO CONVERT KARO - YE LINE REPLACE KARO:
      final jobDataRaw = jobDoc.data()!;
      final jobData = <String, dynamic>{};

      jobDataRaw.forEach((key, value) {
        if (value is Timestamp) {
          jobData[key] = value.toDate().toIso8601String();
        } else if (value is Map) {
          jobData[key] = _convertMapTimestamps(value as Map);
        } else if (value is List) {
          jobData[key] = _convertListTimestamps(value);
        } else {
          jobData[key] = value;
        }
      });
      jobData['id'] = jobDoc.id;

      // CANDIDATES LIST KO BHI CONVERT KARO - YE LINES REPLACE KARO:
      final appliedCandidatesList = candidatesSnapshot.docs
          .where((doc) => doc.data()['jobId'] == firstCandidateJobId)
          .map((doc) {
        final rawData = doc.data();
        final convertedData = <String, dynamic>{};

        rawData.forEach((key, value) {
          if (value is Timestamp) {
            convertedData[key] = value.toDate().toIso8601String();
          } else if (value is Map) {
            convertedData[key] = _convertMapTimestamps(value as Map);
          } else if (value is List) {
            convertedData[key] = _convertListTimestamps(value);
          } else {
            convertedData[key] = value;
          }
        });
        convertedData['id'] = doc.id;

        return convertedData;
      }).toList();

      Navigator.pop(context); // Close loading

      print('Job ID: ${jobData['id']}');
      print('Total candidates: ${appliedCandidatesList.length}');

      // Navigate to matching screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AppliedCandidatesMatchingScreen(
            job: jobData,
            appliedCandidates: appliedCandidatesList,
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      print('Error details: $e'); // Debug ke liye
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

// YE DO HELPER METHODS ADD KARO (same class mein):
  Map<String, dynamic> _convertMapTimestamps(Map map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.toDate().toIso8601String();
      } else if (value is Map) {
        result[key] = _convertMapTimestamps(value);
      } else if (value is List) {
        result[key] = _convertListTimestamps(value);
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  List _convertListTimestamps(List list) {
    return list.map((item) {
      if (item is Timestamp) {
        return item.toDate().toIso8601String();
      } else if (item is Map) {
        return _convertMapTimestamps(item as Map);
      } else if (item is List) {
        return _convertListTimestamps(item);
      }
      return item;
    }).toList();
  }
*/
  void _initFeatures() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final isRecruiter = userProvider.isRecruiter;

    // Clear existing features
    _primaryFeatures.clear();
    _secondaryFeatures.clear();

    if (isRecruiter) {
      // Primary features for recruiters
      _primaryFeatures.addAll([
        Feature(
          icon: Icons.post_add,
          title: 'Post Job',
          color: Color(0xFF0D9488),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DraftJobsScreen()),
            );
          },
        ),
        Feature(
          icon: Icons.description,
          title: 'My Posted Jobs',
          color: Color(0xFF1E3A8A),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PostedJobsScreen()),
            );
          },
        ),
        Feature(
          icon: Icons.people,
          title: 'Candidates Pool',
          color: Color(0xFF4F46E5),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CandidateMatchScreen()),
            );
          },
          // onTap: () => _openCandidatesMatching(context),
        ),
        Feature(
            icon: Icons.event,
            title: 'Scheduled Interviews',
            color: Color(0xFF0891B2),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => InterviewManagementScreen()),
              );
            }),
        Feature(
            icon: Icons.question_answer,
            title: 'Interview Questions',
            color: Color(0xFF0891B2),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => AIInterviewQuestionsScreen()),
              );
            }),
        Feature(
            icon: Icons.mail,
            title: 'Offers Management',
            color: Color.fromARGB(255, 195, 151, 197),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => OfferLetterAutomationScreen()),
              );
            }),
        Feature(
            icon: Icons.message,
            title: 'My Chats',
            color: Color.fromARGB(255, 83, 211, 134),
            onTap: () {
              // Navigator.push(
              // context,
              // MaterialPageRoute(builder: (context) => ChatScreen()),
              //);
            }),
      ]);
    } else {
      // Primary features for job seekers
      _primaryFeatures.addAll([
        Feature(
          icon: Icons.search,
          title: 'Find Jobs',
          color: Color(0xFF1E3A8A),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => CandidateApplicationScreen()),
            );
          },
        ),
        Feature(
          icon: Icons.bookmark,
          title: 'Applied Jobs',
          color: Color(0xFF4F46E5),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AppliedJobsScreen()),
            );
          },
        ),
        Feature(
          icon: Icons.work,
          title: 'My Interviews',
          color: Color(0xFFD97706),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => InterviewScheduleScreen()),
            );
          },
        ),
        Feature(
          icon: Icons.work,
          title: 'Jobs Offered',
          color: Color.fromARGB(255, 212, 154, 207),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => OfferLetterScreen()),
            );
          },
        ),
        Feature(
          icon: Icons.person,
          title: 'My Profile',
          color: Color(0xFF0D9488),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => JobseekerProfileForm()),
            );
          },
        ),
        Feature(
          icon: Icons.message,
          title: 'My Chats',
          color: Color.fromARGB(255, 24, 135, 40),
          onTap: () {
            //   Navigator.push(
            //    context,
            //   MaterialPageRoute(builder: (context) => ChatScreen()),
            //   );
          },
        ),
      ]);
    }

    setState(() {});
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isRecruiter = userProvider.isRecruiter;
    final userName = userProvider.userData?['name'] ?? 'User';

    return Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          'SmartRecruit',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 25,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {
              // Navigate to notifications screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              ).then((_) {
                // Mark notifications as read when returning from the notifications screen
                AppNotificationManager().markNotificationsAsRead();
              });
            },
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Welcome Header
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment
                    .start, // Adjusted to avoid vertical overflow
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 32,
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize:
                          MainAxisSize.min, // Keep column as small as needed
                      children: [
                        Text(
                          'Welcome $userName',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          isRecruiter ? 'Recruiter' : 'Job Seeker',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Primary Features Grid
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 4),
              child: Row(
                children: [
                  Text(
                    isRecruiter ? 'Recruitment Tools' : 'Job Search Tools',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.grid_view_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Primary Features Grid - Fixed grid sizing
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2, // Increased for more height
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _animationController,
                      curve: Interval(
                        index * 0.1,
                        index * 0.1 + 0.4,
                        curve: Curves.easeOut,
                      ),
                    ),
                  );

                  return _buildAnimatedFeatureCard(
                    context,
                    _primaryFeatures[index],
                    animation,
                    isPrimary: true,
                  );
                },
                childCount: _primaryFeatures.length,
              ),
            ),
          ),

          // Secondary Features List
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _animationController,
                      curve: Interval(
                        0.4 + index * 0.1,
                        0.4 + index * 0.1 + 0.4,
                        curve: Curves.easeOut,
                      ),
                    ),
                  );

                  return _buildAnimatedFeatureCard(
                    context,
                    _secondaryFeatures[index],
                    animation,
                    isPrimary: false,
                  );
                },
                childCount: _secondaryFeatures.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedFeatureCard(
      BuildContext context, Feature feature, Animation<double> animation,
      {required bool isPrimary}) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: isPrimary
          ? _buildPrimaryFeatureCard(context, feature)
          : _buildSecondaryFeatureCard(context, feature),
    );
  }

  Widget _buildPrimaryFeatureCard(BuildContext context, Feature feature) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: const Color.fromARGB(255, 49, 84, 112), width: 0.8),
      ),
      child: InkWell(
        onTap: feature.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color.fromARGB(255, 255, 255, 255),
                Colors.blue.shade50
              ],
            ),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: feature.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: feature.color.withOpacity(0.1),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  feature.icon,
                  color: feature.color,
                  size: 28,
                ),
              ),
              SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  feature.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryFeatureCard(BuildContext context, Feature feature) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: const Color.fromARGB(255, 15, 71, 117), width: 0.5),
      ),
      child: InkWell(
        onTap: feature.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.white, Colors.blue.shade50.withOpacity(0.3)],
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: feature.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: feature.color.withOpacity(0.08),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  feature.icon,
                  color: feature.color,
                  size: 22,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  feature.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.blue.shade300,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Simplified Feature class
class Feature {
  final IconData icon;
  final String title;
  final Color color;
  final Function() onTap;

  Feature({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });
}

// Settings Screen with Logout Feature
class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userEmail = userProvider.userData?['email'] ?? 'user@example.com';

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Settings Categories
          _buildSettingsCategory(context, 'Account Settings'),
          _buildSettingsItem(
            context,
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: () {},
          ),
          _buildSettingsItem(
            context,
            icon: Icons.email_outlined,
            title: 'Delete Account',
            subtitle: 'Delete Your Account',
            onTap: () {},
          ),

          _buildSettingsCategory(context, 'Appearance'),
          _buildSwitchItem(
            context,
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            value: userProvider.isDarkMode,
            onChanged: (value) {
              userProvider.toggleDarkMode();
            },
          ),

          _buildSettingsCategory(context, 'Notifications'),
          _buildSwitchItem(
            context,
            icon: Icons.notifications_outlined,
            title: 'App Notifications',
            value: userProvider.enableNotifications,
            onChanged: (value) {
              userProvider.toggleNotifications();
            },
          ),

          // Logout Button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ElevatedButton(
              onPressed: () async {
                await firebase_auth.FirebaseAuth.instance.signOut();
                userProvider.signOut();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFEF4444),
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSettingsCategory(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Divider(thickness: 1),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).primaryColor,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Color(0xFF64748B),
          fontSize: 14,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Color(0xFF94A3B8),
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).primaryColor,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).primaryColor,
      ),
    );
  }
}

// Loading Screen
class LoadingScreen extends StatefulWidget {
  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF1F5F9),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo and pulse animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.work_outline_rounded,
                        color: Colors.white,
                        size: 65,
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 40),

              // App name with shadow
              Text(
                'SmartRecruit',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black12,
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 12),

              // Tagline with faded background
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'Finding your perfect match',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              SizedBox(height: 60),

              // Custom loading animation
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor),
                      strokeWidth: 3,
                      backgroundColor: Colors.grey.withOpacity(0.1),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationAnimation.value,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor,
                                Color(0xFF0D9488),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            Icons.search,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              SizedBox(height: 40),

              // Loading text with fade animation
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(0.4, 1.0),
                ),
                child: Text(
                  'Loading your opportunities...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResumeUploadScreen extends StatefulWidget {
  const ResumeUploadScreen({Key? key}) : super(key: key);

  @override
  State<ResumeUploadScreen> createState() => _ResumeUploadScreenState();
}

class _ResumeUploadScreenState extends State<ResumeUploadScreen> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/HomeScreen'),
            child: const Text(
              'Skip for now',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.primaryColor.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Icon(
                        Icons.assignment_ind,
                        size: 80,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Complete your profile for better job matches',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'A complete profile increases your chances of finding the perfect job by 70%',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Feature list
                    _buildFeatureItem(
                      context,
                      Icons.visibility,
                      'Enhanced Visibility',
                      'Be more visible to potential employers',
                    ),
                    _buildFeatureItem(
                      context,
                      Icons.check_circle_outline,
                      'Better Matches',
                      'Receive more relevant job recommendations',
                    ),
                    _buildFeatureItem(
                      context,
                      Icons.speed,
                      'Faster Applications',
                      'Apply with just one click using your profile',
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            // Bottom section with checkbox and button
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Don't show again checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _dontShowAgain,
                        onChanged: (value) {
                          setState(() {
                            _dontShowAgain = value ?? false;
                            // Update global preference
                            GlobalPreferences.dontShowResumeUploadScreen =
                                _dontShowAgain;
                          });
                        },
                        activeColor: theme.primaryColor,
                      ),
                      const Text(
                        "Don't show again",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const JobseekerProfileForm(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class JobseekerProfileForm extends StatefulWidget {
  final File? resumeFile;

  const JobseekerProfileForm({Key? key, this.resumeFile}) : super(key: key);

  @override
  State<JobseekerProfileForm> createState() => _JobseekerProfileFormState();
}

class _JobseekerProfileFormState extends State<JobseekerProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _auth = firebase_auth.FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  // User basic info controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _linkedinController = TextEditingController();
  final TextEditingController _githubController = TextEditingController();
  final TextEditingController _portfolioController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _technicalSkillController =
      TextEditingController();
  final TextEditingController _softSkillController = TextEditingController();
  final TextEditingController _languageController = TextEditingController();

  // Skills and experience
  List<String> _technicalSkills = [];
  List<String> _softSkills = [];
  List<String> _languages = [];

  final List<String> _allTechnicalSkills = [
    'Flutter',
    'Firebase',
    'Dart',
    'Python',
    'Java',
    'React',
    'JavaScript',
    'SQL',
    'Node.js',
    'AWS',
    'Swift',
    'Kotlin',
    'C#',
    'HTML/CSS',
    'PHP',
    'Go',
    'Ruby',
    'TypeScript'
  ];

  final List<String> _allSoftSkills = [
    'Communication',
    'Teamwork',
    'Problem-solving',
    'Time management',
    'Leadership',
    'Adaptability',
    'Project management',
    'Critical thinking',
    'Conflict resolution',
    'Emotional intelligence',
    'Creativity'
  ];

  final List<String> _allLanguages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Japanese',
    'Russian',
    'Arabic',
    'Portuguese',
    'Hindi',
    'Italian'
  ];

  // Education, work experience, projects and certificates
  List<Map<String, dynamic>> _educations = [];
  List<Map<String, dynamic>> _workExperiences = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _certificates = [];

  // Files
  File? _resumeFile;
  File? _profilePicFile;
  String? _resumeUrl;
  String? _profilePicUrl;

  bool _isLoading = true;
  bool _isSaving = false;
  int _currentStep = 0;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream;

  // Theme colors
  final Color _primaryColor = const Color(0xFF3366FF);
  final Color _accentColor = const Color(0xFF00C8FF);
  final Color _warningColor = const Color(0xFFFFA500);
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _dangerColor = const Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _resumeFile = widget.resumeFile;

    // Set email from current user
    _emailController.text = _auth.currentUser?.email ?? '';

    _profileStream = _firestore
        .collection('JobSeekersProfiles')
        .doc(_auth.currentUser!.uid)
        .snapshots();
    _loadProfile();
  }

  @override
  void dispose() {
    _technicalSkillController.dispose();
    _softSkillController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final uid = _auth.currentUser!.uid;
      final doc =
          await _firestore.collection('JobSeekersProfiles').doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;

        // Basic info
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _locationController.text = data['location'] ?? '';
        _linkedinController.text = data['linkedin'] ?? '';
        _githubController.text = data['github'] ?? '';
        _portfolioController.text = data['portfolio'] ?? '';
        _summaryController.text = data['summary'] ?? '';

        // Skills and languages
        _technicalSkills = List<String>.from(data['technicalSkills'] ?? []);
        _softSkills = List<String>.from(data['softSkills'] ?? []);
        _languages = List<String>.from(data['languages'] ?? []);

        // Education, experiences, projects and certificates
        _educations = List<Map<String, dynamic>>.from(data['educations'] ?? []);
        _workExperiences =
            List<Map<String, dynamic>>.from(data['workExperiences'] ?? []);
        _projects = List<Map<String, dynamic>>.from(data['projects'] ?? []);
        _certificates =
            List<Map<String, dynamic>>.from(data['certificates'] ?? []);

        // URLs
        _resumeUrl = data['resumeUrl'];
        _profilePicUrl = data['profilePicUrl'];
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickResume() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);
    if (result != null) {
      setState(() => _resumeFile = File(result.files.single.path!));
    }
  }

  Future<void> _pickProfilePic() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _profilePicFile = File(picked.path));
    }
  }

  Future<String?> _uploadToSupabase(
      File file, String path, String? oldFileUrl) async {
    try {
      final fileName =
          '${_auth.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
      final fullPath = '$path/$fileName';

      // Delete old file if exists
      if (oldFileUrl != null && oldFileUrl.isNotEmpty) {
        try {
          final oldPath = oldFileUrl
              .split('/storage/v1/object/public/smartrecruitfiles/')
              .last;
          await _supabase.storage.from('smartrecruitfiles').remove([oldPath]);
        } catch (e) {
          debugPrint('Failed to delete old file: $e');
        }
      }

      // Upload new file
      await _supabase.storage
          .from('smartrecruitfiles')
          .upload(fullPath, file, fileOptions: const FileOptions(upsert: true));
      return _supabase.storage.from('smartrecruitfiles').getPublicUrl(fullPath);
    } catch (e) {
      debugPrint('Upload failed: $e');
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Please fix the errors in the form'),
            ],
          ),
          backgroundColor: _dangerColor,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = _auth.currentUser!.uid;

      // Upload files if selected (separate try for files, so skills save even if upload fails)
      String? newResumeUrl = _resumeUrl;
      String? newProfilePicUrl = _profilePicUrl;

      try {
        if (_resumeFile != null) {
          newResumeUrl =
              await _uploadToSupabase(_resumeFile!, 'resumes', _resumeUrl);
        }
        if (_profilePicFile != null) {
          newProfilePicUrl = await _uploadToSupabase(
              _profilePicFile!, 'profile_pics', _profilePicUrl);
        }
      } catch (uploadError) {
        debugPrint('File upload failed but continuing with save: $uploadError');
        // Don't throw, just log – use old URLs if upload fails
      }

      // Debug print skills before save
      debugPrint('Saving Profile - Technical Skills: $_technicalSkills');
      debugPrint('Saving Profile - Soft Skills: $_softSkills');
      debugPrint('Saving Profile - Languages: $_languages');

      // Save all data to Firestore (now with updated URLs)
      await _firestore.collection('JobSeekersProfiles').doc(uid).set({
        'userId': uid,
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'location': _locationController.text,
        'linkedin': _linkedinController.text,
        'github': _githubController.text,
        'portfolio': _portfolioController.text,
        'summary': _summaryController.text,
        'technicalSkills': _technicalSkills,
        'softSkills': _softSkills,
        'languages': _languages,
        'educations': _educations,
        'workExperiences': _workExperiences,
        'projects': _projects,
        'certificates': _certificates,
        'resumeUrl': newResumeUrl,
        'profilePicUrl': newProfilePicUrl,
        'profileCompletionPercentage': _calculateProfileCompletion(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Profile saved successfully to Firestore');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Profile updated successfully!'),
            ],
          ),
          backgroundColor: _successColor,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      // Navigate to Home screen
      Navigator.pushReplacementNamed(context, '/HomeScreen');
    } catch (e) {
      debugPrint('Error in _submitForm: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Error updating profile: $e')),
            ],
          ),
          backgroundColor: _dangerColor,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  int _calculateProfileCompletion() {
    int total = 0;
    int completed = 0;

    // Basic info - 30%
    total += 6;
    if (_nameController.text.isNotEmpty) completed++;
    if (_emailController.text.isNotEmpty) completed++;
    if (_phoneController.text.isNotEmpty) completed++;
    if (_locationController.text.isNotEmpty) completed++;
    if (_summaryController.text.isNotEmpty) completed++;
    if (_profilePicUrl != null) completed++;

    // Resume - 10%
    total += 1;
    if (_resumeUrl != null) completed++;

    // Skills - 15%
    total += 3;
    if (_technicalSkills.isNotEmpty) completed++;
    if (_softSkills.isNotEmpty) completed++;
    if (_languages.isNotEmpty) completed++;

    // Experience and education - 45%
    total += 4;
    if (_educations.isNotEmpty) completed++;
    if (_workExperiences.isNotEmpty) completed++;
    if (_projects.isNotEmpty) completed++;
    if (_certificates.isNotEmpty) completed++;

    return ((completed / total) * 100).round();
  }

  void _addEducation() {
    showDialog(
      context: context,
      builder: (context) => _EducationDialog(
        onSave: (education) {
          setState(() => _educations.add(education));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _editEducation(int index) {
    showDialog(
      context: context,
      builder: (context) => _EducationDialog(
        education: _educations[index],
        onSave: (education) {
          setState(() => _educations[index] = education);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _addTechnicalSkill(String skill) {
    if (skill.trim().isNotEmpty && !_technicalSkills.contains(skill.trim())) {
      setState(() => _technicalSkills.add(skill.trim()));
    }
  }

  void _addSoftSkill(String skill) {
    if (skill.trim().isNotEmpty && !_softSkills.contains(skill.trim())) {
      setState(() => _softSkills.add(skill.trim()));
    }
  }

  void _addLanguage(String language) {
    if (language.trim().isNotEmpty && !_languages.contains(language.trim())) {
      setState(() => _languages.add(language.trim()));
    }
  }

  void _removeTechnicalSkill(String skill) {
    setState(() => _technicalSkills.remove(skill));
  }

  void _removeSoftSkill(String skill) {
    setState(() => _softSkills.remove(skill));
  }

  void _removeLanguage(String language) {
    setState(() => _languages.remove(language));
  }

  void _addWorkExperience() {
    showDialog(
      context: context,
      builder: (context) => _WorkExperienceDialog(
        onSave: (experience) {
          setState(() => _workExperiences.add(experience));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _editWorkExperience(int index) {
    showDialog(
      context: context,
      builder: (context) => _WorkExperienceDialog(
        experience: _workExperiences[index],
        onSave: (experience) {
          setState(() => _workExperiences[index] = experience);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _addProject() {
    showDialog(
      context: context,
      builder: (context) => _ProjectDialog(
        onSave: (project) {
          setState(() => _projects.add(project));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _editProject(int index) {
    showDialog(
      context: context,
      builder: (context) => _ProjectDialog(
        project: _projects[index],
        onSave: (project) {
          setState(() => _projects[index] = project);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _addCertificate() {
    showDialog(
      context: context,
      builder: (context) => _CertificateDialog(
        onSave: (certificate) {
          setState(() => _certificates.add(certificate));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _editCertificate(int index) {
    showDialog(
      context: context,
      builder: (context) => _CertificateDialog(
        certificate: _certificates[index],
        onSave: (certificate) {
          setState(() => _certificates[index] = certificate);
          Navigator.pop(context);
        },
      ),
    );
  }

  // Custom text field with consistent styling
  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    IconData? prefixIcon,
    String? hintText,
    bool isRequired = false,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          hintText: hintText,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: _primaryColor)
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _dangerColor),
          ),
          filled: true,
          fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: TextStyle(fontSize: 15),
        readOnly: readOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator ??
            (isRequired
                ? (value) => value == null || value.isEmpty
                    ? 'This field is required'
                    : null
                : null),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickProfilePic,
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                      image: _profilePicFile != null
                          ? DecorationImage(
                              image: FileImage(_profilePicFile!),
                              fit: BoxFit.cover,
                            )
                          : _profilePicUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(_profilePicUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                    ),
                    child: (_profilePicFile == null && _profilePicUrl == null)
                        ? Icon(Icons.person,
                            size: 60, color: Colors.grey.shade400)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                Divider(height: 30, thickness: 1),
                _buildStyledTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  prefixIcon: Icons.person_outline,
                  isRequired: true,
                  validator: (value) =>
                      value!.isEmpty ? 'Name is required' : null,
                ),
                _buildStyledTextField(
                  controller: _emailController,
                  label: 'Email',
                  prefixIcon: Icons.email_outlined,
                  isRequired: true,
                  readOnly: true,
                  keyboardType: TextInputType.emailAddress,
                ),
                _buildStyledTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  prefixIcon: Icons.phone_outlined,
                  isRequired: true,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Phone number is required';
                    return value.length >= 10
                        ? null
                        : 'Enter a valid phone number';
                  },
                ),
                _buildStyledTextField(
                  controller: _locationController,
                  label: 'Location',
                  prefixIcon: Icons.location_on_outlined,
                  hintText: 'City, Country',
                  isRequired: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Social Media & Online Presence',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                Divider(height: 30, thickness: 1),
                _buildStyledTextField(
                  controller: _linkedinController,
                  label: 'LinkedIn Profile',
                  prefixIcon: Icons.link,
                  keyboardType: TextInputType.url,
                ),
                _buildStyledTextField(
                  controller: _githubController,
                  label: 'GitHub Profile',
                  prefixIcon: Icons.code,
                  keyboardType: TextInputType.url,
                ),
                _buildStyledTextField(
                  controller: _portfolioController,
                  label: 'Portfolio Website',
                  prefixIcon: Icons.web,
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeAndSummaryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Professional Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Provide a brief overview of your professional background and key strengths.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStyledTextField(
                  controller: _summaryController,
                  label: 'Summary',
                  isRequired: true,
                  maxLines: 5,
                  hintText:
                      'Share your professional story and highlight your key qualifications and career goals.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resume/CV',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Upload your resume to help employers find you faster.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                if (_resumeFile != null || _resumeUrl != null)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.description, color: _primaryColor),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _resumeFile != null
                                    ? p.basename(_resumeFile!.path)
                                    : 'Resume uploaded',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _resumeFile != null
                                    ? 'New file to upload'
                                    : 'Click to preview',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              color: _dangerColor),
                          onPressed: () => setState(() => _resumeFile != null
                              ? _resumeFile = null
                              : _resumeUrl = null),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 30),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                          style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file,
                            size: 48, color: Colors.grey.shade500),
                        SizedBox(height: 16),
                        Text(
                          'Drag and drop your resume here',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text('or',
                            style: TextStyle(color: Colors.grey.shade500)),
                        SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _pickResume,
                          icon: Icon(Icons.file_upload),
                          label: Text('Browse Files'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Supported formats: PDF, DOC, DOCX',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Technical Skills',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Enter your technical skills (e.g., Flutter, Python).',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                // Existing skills as removable chips
                if (_technicalSkills.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _technicalSkills
                        .map((skill) => InputChip(
                              label: Text(skill),
                              onDeleted: () => _removeTechnicalSkill(skill),
                              backgroundColor: _primaryColor.withOpacity(0.1),
                              deleteIconColor: _dangerColor,
                            ))
                        .toList(),
                  ),
                // Add new skill field
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _technicalSkillController,
                        onSubmitted: _addTechnicalSkill,
                        decoration: InputDecoration(
                          hintText: 'Enter a technical skill...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: _primaryColor, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        _addTechnicalSkill(_technicalSkillController.text);
                        _technicalSkillController.clear();
                      },
                      child: const Icon(Icons.add),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Soft Skills',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Enter your soft skills (e.g., Communication, Leadership).',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                // Existing skills as removable chips
                if (_softSkills.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _softSkills
                        .map((skill) => InputChip(
                              label: Text(skill),
                              onDeleted: () => _removeSoftSkill(skill),
                              backgroundColor: _accentColor.withOpacity(0.1),
                              deleteIconColor: _dangerColor,
                            ))
                        .toList(),
                  ),
                // Add new skill field
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _softSkillController,
                        onSubmitted: _addSoftSkill,
                        decoration: InputDecoration(
                          hintText: 'Enter a soft skill...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: _accentColor, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        _addSoftSkill(_softSkillController.text);
                        _softSkillController.clear();
                      },
                      child: const Icon(Icons.add),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Languages',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Enter languages you speak (e.g., English, Spanish).',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                // Existing languages as removable chips
                if (_languages.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _languages
                        .map((language) => InputChip(
                              label: Text(language),
                              onDeleted: () => _removeLanguage(language),
                              backgroundColor: _primaryColor.withOpacity(0.1),
                              deleteIconColor: _dangerColor,
                            ))
                        .toList(),
                  ),
                // Add new language field
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _languageController,
                        onSubmitted: _addLanguage,
                        decoration: InputDecoration(
                          hintText: 'Enter a language...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: _primaryColor, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        _addLanguage(_languageController.text);
                        _languageController.clear();
                      },
                      child: const Icon(Icons.add),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(0.0),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Education',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(
                    height: 10), // Add spacing between title and button
                ElevatedButton.icon(
                  onPressed: _addEducation,
                  icon: Icon(Icons.add),
                  label: Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Add your educational background and qualifications.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            _educations.isEmpty
                ? Center(
                    child: Container(
                      padding: EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No education added yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap "Add Education" to include your educational background.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _educations.length,
                    itemBuilder: (context, index) {
                      final education = _educations[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.school,
                                        color: _primaryColor),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          education['school'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          education['degree'] ?? '',
                                          style: TextStyle(
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          '${education['startDate']} - ${education['endDate']}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (education['description']
                                                ?.isNotEmpty ??
                                            false)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              education['description'],
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Divider(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _editEducation(index),
                                    icon: Icon(Icons.edit, size: 18),
                                    label: Text('Edit'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _primaryColor,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _educations.removeAt(index);
                                      });
                                    },
                                    icon: Icon(Icons.delete, size: 18),
                                    label: Text('Delete'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _dangerColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkExperienceStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(0.0),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Work Experience',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _addWorkExperience,
                  icon: Icon(Icons.add),
                  label: Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Add your professional experience and work history.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            _workExperiences.isEmpty
                ? Center(
                    child: Container(
                      padding: EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.business_center_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No work experience added yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap "Add Experience" to include your professional experience.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _workExperiences.length,
                    itemBuilder: (context, index) {
                      final experience = _workExperiences[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _accentColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child:
                                        Icon(Icons.work, color: _accentColor),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          experience['title'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          experience['company'] ?? '',
                                          style: TextStyle(
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          '${experience['startDate']} - ${experience['endDate']}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (experience['description']
                                                ?.isNotEmpty ??
                                            false)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              experience['description'],
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Divider(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _editWorkExperience(index),
                                    icon: Icon(Icons.edit, size: 18),
                                    label: Text('Edit'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _primaryColor,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _workExperiences.removeAt(index);
                                      });
                                    },
                                    icon: Icon(Icons.delete, size: 18),
                                    label: Text('Delete'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _dangerColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(0.0),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Projects',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _addProject,
                  icon: Icon(Icons.add),
                  label: Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Showcase your personal and professional projects.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            _projects.isEmpty
                ? Center(
                    child: Container(
                      padding: EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.code_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No projects added yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap "Add Project" to showcase your work and achievements.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _projects.length,
                    itemBuilder: (context, index) {
                      final project = _projects[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.lightbulb,
                                        color: _primaryColor),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          project['title'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          project['date'] ?? '',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (project['link']?.isNotEmpty ??
                                            false)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4.0),
                                            child: Row(
                                              children: [
                                                Icon(Icons.link,
                                                    size: 16,
                                                    color: _accentColor),
                                                SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    project['link'],
                                                    style: TextStyle(
                                                      color: _accentColor,
                                                      fontSize: 14,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (project['description']
                                                ?.isNotEmpty ??
                                            false)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              project['description'],
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Divider(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _editProject(index),
                                    icon: Icon(Icons.edit, size: 18),
                                    label: Text('Edit'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _primaryColor,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _projects.removeAt(index);
                                      });
                                    },
                                    icon: Icon(Icons.delete, size: 18),
                                    label: Text('Delete'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _dangerColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificatesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(0.0),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Certificates',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addCertificate,
                  icon: Icon(Icons.add),
                  label: Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Showcase your certifications and achievements.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            _certificates.isEmpty
                ? Center(
                    child: Container(
                      padding: EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.emoji_events_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No certificates added yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap "Add" to include your certifications and achievements.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _certificates.length,
                    itemBuilder: (context, index) {
                      final certificate = _certificates[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.verified,
                                        color: _primaryColor),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          certificate['name'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          certificate['issuer'] ?? '',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Row(
                                            children: [
                                              Icon(Icons.calendar_today,
                                                  size: 16,
                                                  color: Colors.grey.shade600),
                                              SizedBox(width: 6),
                                              Text(
                                                'Issued: ${certificate['date']}',
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    color:
                                                        Colors.grey.shade600),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (certificate['credentialId']
                                                ?.isNotEmpty ??
                                            false)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4.0),
                                            child: Row(
                                              children: [
                                                Icon(Icons.badge,
                                                    size: 16,
                                                    color:
                                                        Colors.grey.shade600),
                                                SizedBox(width: 6),
                                                Text(
                                                  'ID: ${certificate['credentialId']}',
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      color:
                                                          Colors.grey.shade600),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (certificate['link']?.isNotEmpty ??
                                            false)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4.0),
                                            child: Row(
                                              children: [
                                                Icon(Icons.link,
                                                    size: 16,
                                                    color: _accentColor),
                                                SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    certificate['link'],
                                                    style: TextStyle(
                                                      color: _accentColor,
                                                      fontSize: 14,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (certificate['description']
                                                ?.isNotEmpty ??
                                            false)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              certificate['description'],
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Divider(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _editCertificate(index),
                                    icon: Icon(Icons.edit, size: 18),
                                    label: Text('Edit'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _primaryColor,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _certificates.removeAt(index);
                                      });
                                    },
                                    icon: Icon(Icons.delete, size: 18),
                                    label: Text('Delete'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _dangerColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    final completionPercentage = _calculateProfileCompletion();
    final Color progressColor = completionPercentage < 50
        ? Colors.red
        : completionPercentage < 80
            ? Colors.orange
            : Colors.green;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                const Text(
                  'Profile Completion',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 150,
                      width: 150,
                      child: CircularProgressIndicator(
                        value: completionPercentage / 100,
                        strokeWidth: 15,
                        backgroundColor: Colors.grey[300],
                        valueColor:
                            AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                    Text(
                      '$completionPercentage%',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          const Text(
            'Profile Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReviewItem(
                      'Basic Information',
                      _nameController.text.isNotEmpty
                          ? 'Complete'
                          : 'Incomplete'),
                  _buildReviewItem(
                      'Resume',
                      _resumeUrl != null || _resumeFile != null
                          ? 'Uploaded'
                          : 'Not uploaded'),
                  _buildReviewItem(
                      'Professional Summary',
                      _summaryController.text.isNotEmpty
                          ? 'Added'
                          : 'Not added'),
                  _buildReviewItem('Technical Skills',
                      '${_technicalSkills.length} selected'),
                  _buildReviewItem(
                      'Soft Skills', '${_softSkills.length} selected'),
                  _buildReviewItem(
                      'Languages', '${_languages.length} selected'),
                  _buildReviewItem(
                      'Education', '${_educations.length} entries'),
                  _buildReviewItem(
                      'Work Experience', '${_workExperiences.length} entries'),
                  _buildReviewItem('Projects', '${_projects.length} entries'),
                  _buildReviewItem(
                      'Certificates', '${_certificates.length} entries'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recommendations to improve your profile:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_resumeUrl == null && _resumeFile == null)
                    const ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text('Upload your resume to improve job matching'),
                    ),
                  if (_summaryController.text.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text('Add a professional summary to stand out'),
                    ),
                  if (_technicalSkills.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text(
                          'Select relevant technical skills to match with jobs'),
                    ),
                  if (_educations.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text('Add your educational background'),
                    ),
                  if (_workExperiences.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text(
                          'Add your work experience to showcase your expertise'),
                    ),
                  if (_projects.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text(
                          'Add projects to demonstrate your practical skills'),
                    ),
                  if (_certificates.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text('Add certifications to validate your skills'),
                    ),
                  if (completionPercentage >= 80)
                    const ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text(
                          'Your profile is looking great! Ready to find jobs.'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  color: value.contains('Not') ||
                          value.contains('0 ') ||
                          value == 'Incomplete'
                      ? Colors.red
                      : Colors.black)),
        ],
      ),
    );
  }

  List<Step> get _steps => [
        Step(
          title: const Text('Basic Info'),
          content: _buildBasicInfoStep(),
          isActive: _currentStep >= 0,
        ),
        Step(
          title: const Text('Resume & Summary'),
          content: _buildResumeAndSummaryStep(),
          isActive: _currentStep >= 1,
        ),
        Step(
          title: const Text('Skills'),
          content: _buildSkillsStep(),
          isActive: _currentStep >= 2,
        ),
        Step(
          title: const Text('Education'),
          content: _buildEducationStep(),
          isActive: _currentStep >= 3,
        ),
        Step(
          title: const Text('Experience'),
          content: _buildWorkExperienceStep(),
          isActive: _currentStep >= 4,
        ),
        Step(
          title: const Text('Projects'),
          content: _buildProjectsStep(),
          isActive: _currentStep >= 5,
        ),
        Step(
          title: const Text('Certificates'),
          content: _buildCertificatesStep(),
          isActive: _currentStep >= 6,
        ),
        Step(
          title: const Text('Review'),
          content: _buildReviewStep(),
          isActive: _currentStep >= 7,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Stepper(
                type: StepperType.vertical,
                currentStep: _currentStep,
                onStepTapped: (step) => setState(() => _currentStep = step),
                onStepContinue: () {
                  if (_currentStep < _steps.length - 1) {
                    setState(() => _currentStep += 1);
                  } else {
                    _submitForm();
                  }
                },
                onStepCancel: () {
                  if (_currentStep > 0) {
                    setState(() => _currentStep -= 1);
                  }
                },
                steps: _steps,
                controlsBuilder: (context, details) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: details.onStepContinue,
                          child: Text(_currentStep == _steps.length - 1
                              ? 'Submit'
                              : 'Continue'),
                        ),
                        const SizedBox(width: 12),
                        if (_currentStep > 0)
                          OutlinedButton(
                            onPressed: details.onStepCancel,
                            child: const Text('Back'),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
      bottomNavigationBar: _isSaving ? const LinearProgressIndicator() : null,
    );
  }
}

// Dialog widgets for adding/editing entries
class _EducationDialog extends StatefulWidget {
  final Map<String, dynamic>? education;
  final Function(Map<String, dynamic>) onSave;

  const _EducationDialog({
    Key? key,
    this.education,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_EducationDialog> createState() => _EducationDialogState();
}

class _EducationDialogState extends State<_EducationDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _degreeController = TextEditingController();
  final TextEditingController _fieldController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _gpaController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.education != null) {
      _schoolController.text = widget.education!['school'] ?? '';
      _degreeController.text = widget.education!['degree'] ?? '';
      _fieldController.text = widget.education!['field'] ?? '';
      _startDateController.text = widget.education!['startDate'] ?? '';
      _endDateController.text = widget.education!['endDate'] ?? '';
      _gpaController.text = widget.education!['gpa'] ?? '';
      _descriptionController.text = widget.education!['description'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.education == null ? 'Add Education' : 'Edit Education'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _schoolController,
                decoration: const InputDecoration(
                  labelText: 'School/University *',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _degreeController,
                decoration: const InputDecoration(
                  labelText: 'Degree *',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _fieldController,
                decoration: const InputDecoration(
                  labelText: 'Field of Study *',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _startDateController,
                decoration: const InputDecoration(
                  labelText: 'Start Date *',
                  hintText: 'MM/YYYY',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _endDateController,
                decoration: const InputDecoration(
                  labelText: 'End Date *',
                  hintText: 'MM/YYYY or Present',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _gpaController,
                decoration: const InputDecoration(
                  labelText: 'GPA',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave({
                'school': _schoolController.text,
                'degree': _degreeController.text,
                'field': _fieldController.text,
                'startDate': _startDateController.text,
                'endDate': _endDateController.text,
                'gpa': _gpaController.text,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _WorkExperienceDialog extends StatefulWidget {
  final Map<String, dynamic>? experience;
  final Function(Map<String, dynamic>) onSave;

  const _WorkExperienceDialog({
    Key? key,
    this.experience,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_WorkExperienceDialog> createState() => _WorkExperienceDialogState();
}

class _WorkExperienceDialogState extends State<_WorkExperienceDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _currentlyWorking = false;

  @override
  void initState() {
    super.initState();
    if (widget.experience != null) {
      _titleController.text = widget.experience!['title'] ?? '';
      _companyController.text = widget.experience!['company'] ?? '';
      _locationController.text = widget.experience!['location'] ?? '';
      _startDateController.text = widget.experience!['startDate'] ?? '';
      _endDateController.text = widget.experience!['endDate'] ?? '';
      _descriptionController.text = widget.experience!['description'] ?? '';
      _currentlyWorking = widget.experience!['endDate'] == 'Present';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.experience == null
          ? 'Add Work Experience'
          : 'Edit Work Experience'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Job Title *',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: 'Company *',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'City, Country',
                ),
              ),
              TextFormField(
                controller: _startDateController,
                decoration: const InputDecoration(
                  labelText: 'Start Date *',
                  hintText: 'MM/YYYY',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              CheckboxListTile(
                title: const Text('I currently work here'),
                value: _currentlyWorking,
                onChanged: (value) {
                  setState(() {
                    _currentlyWorking = value!;
                    if (_currentlyWorking) {
                      _endDateController.text = 'Present';
                    } else {
                      _endDateController.text = '';
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (!_currentlyWorking)
                TextFormField(
                  controller: _endDateController,
                  decoration: const InputDecoration(
                    labelText: 'End Date *',
                    hintText: 'MM/YYYY',
                  ),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave({
                'title': _titleController.text,
                'company': _companyController.text,
                'location': _locationController.text,
                'startDate': _startDateController.text,
                'endDate': _endDateController.text,
                'description': _descriptionController.text,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ProjectDialog extends StatefulWidget {
  final Map<String, dynamic>? project;
  final Function(Map<String, dynamic>) onSave;

  const _ProjectDialog({
    Key? key,
    this.project,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<_ProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.project != null) {
      _titleController.text = widget.project!['title'] ?? '';
      _dateController.text = widget.project!['date'] ?? '';
      _linkController.text = widget.project!['link'] ?? '';
      _descriptionController.text = widget.project!['description'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.project == null ? 'Add Project' : 'Edit Project'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Project Title *',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date *',
                  hintText: 'MM/YYYY or date range',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(
                  labelText: 'Project Link',
                ),
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Technologies used, your role, achievements, etc.',
                ),
                maxLines: 5,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave({
                'title': _titleController.text,
                'date': _dateController.text,
                'link': _linkController.text,
                'description': _descriptionController.text,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _CertificateDialog extends StatefulWidget {
  final Map<String, dynamic>? certificate;
  final Function(Map<String, dynamic>) onSave;

  const _CertificateDialog({
    Key? key,
    this.certificate,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_CertificateDialog> createState() => _CertificateDialogState();
}

class _CertificateDialogState extends State<_CertificateDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _issuerController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _credentialIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.certificate != null) {
      _nameController.text = widget.certificate!['name'] ?? '';
      _issuerController.text = widget.certificate!['issuer'] ?? '';
      _dateController.text = widget.certificate!['date'] ?? '';
      _linkController.text = widget.certificate!['link'] ?? '';
      _credentialIdController.text = widget.certificate!['credentialId'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.certificate == null ? 'Add Certificate' : 'Edit Certificate'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Certificate Name *',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _issuerController,
                decoration: const InputDecoration(
                  labelText: 'Issuing Organization *',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Issue Date *',
                  hintText: 'MM/YYYY',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _credentialIdController,
                decoration: const InputDecoration(
                  labelText: 'Credential ID',
                ),
              ),
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(
                  labelText: 'Certificate URL',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave({
                'name': _nameController.text,
                'issuer': _issuerController.text,
                'date': _dateController.text,
                'link': _linkController.text,
                'credentialId': _credentialIdController.text,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
