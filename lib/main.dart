import 'package:custom_navigator/custom_navigator.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:freezer/ui/library.dart';
import 'package:freezer/ui/login_screen.dart';
import 'package:freezer/ui/search.dart';
import 'package:move_to_background/move_to_background.dart';

import 'ui/player_bar.dart';
import 'api/deezer.dart';
import 'settings.dart';
import 'ui/cached_image.dart';
import 'api/download.dart';
import 'api/player.dart';
import 'ui/home_screen.dart';


Function updateTheme;
Function logOut;
GlobalKey<NavigatorState> mainNavigatorKey = GlobalKey<NavigatorState>();
GlobalKey<NavigatorState> navigatorKey;

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  //Initialize globals
  settings = await Settings().loadSettings();
  await imagesDatabase.init();
  await downloadManager.init();

  runApp(FreezerApp());
}

class FreezerApp extends StatefulWidget {
  @override
  _FreezerAppState createState() => _FreezerAppState();
}

class _FreezerAppState extends State<FreezerApp> {
  @override
  void initState() {
    //Make update theme global
    updateTheme = _updateTheme;
    super.initState();
  }

  void _updateTheme() {
    setState(() {
      settings.themeData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'freezer',
      theme: settings.themeData,
      home: WillPopScope(
        onWillPop: () async {
          //For some reason AudioServiceWidget caused the app to freeze after 2 back button presses. "fix"
          if (navigatorKey.currentState.canPop()) {
            await navigatorKey.currentState.maybePop();
            return false;
          }
          await MoveToBackground.moveTaskToBack();
          return false;
        },
        child: LoginMainWrapper(),
      ),
      navigatorKey: mainNavigatorKey,
    );
  }
}

//Wrapper for login and main screen.
class LoginMainWrapper extends StatefulWidget {
  @override
  _LoginMainWrapperState createState() => _LoginMainWrapperState();
}

class _LoginMainWrapperState extends State<LoginMainWrapper> {

  @override
  void initState() {
    if (settings.arl != null) {
      playerHelper.start();
      //Load token on background
      deezerAPI.arl = settings.arl;
      settings.offlineMode = true;
      deezerAPI.authorize().then((b) {
        if (b) setState(() => settings.offlineMode = false);
      });
    }
    //Global logOut function
    logOut = _logOut;

    super.initState();
  }

  Future _logOut() async {
    setState(() {
      settings.arl = null;
      settings.offlineMode = true;
      deezerAPI = new DeezerAPI();
    });
    await settings.save();
  }

  @override
  Widget build(BuildContext context) {
    if (settings.arl == null)
      return LoginWidget(callback: () => setState(() => {}),);
    return MainScreen();
  }
}



class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

  List<Widget> _screens = [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen()
  ];
  int _selected = 0;

  @override
  void initState() {
    navigatorKey = GlobalKey<NavigatorState>();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PlayerBar(),
          BottomNavigationBar(
            backgroundColor: Theme.of(context).bottomAppBarColor,
            currentIndex: _selected,
            onTap: (int s) async {
              //Pop all routes until home screen

              while (navigatorKey.currentState.canPop()) {
                await navigatorKey.currentState.maybePop();
              }

              await navigatorKey.currentState.maybePop();
              setState(() {
                _selected = s;
              });
            },
            selectedItemColor: Theme.of(context).primaryColor,
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  title: Text('Home')
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                title: Text('Search'),
              ),
              BottomNavigationBarItem(
                  icon: Icon(Icons.library_music),
                  title: Text('Library')
              )
            ],
          )
        ],
      ),
      body: AudioServiceWidget(
        child: CustomNavigator(
          navigatorKey: navigatorKey,
          home:  _screens[_selected],
          pageRoute: PageRoutes.materialPageRoute,
        ),
      )
    );
  }
}
