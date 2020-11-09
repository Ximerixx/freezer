import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:custom_navigator/custom_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:freezer/api/cache.dart';
import 'package:freezer/api/definitions.dart';
import 'package:freezer/ui/library.dart';
import 'package:freezer/ui/login_screen.dart';
import 'package:freezer/ui/search.dart';
import 'package:i18n_extension/i18n_widget.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:freezer/translations.i18n.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:uni_links/uni_links.dart';

import 'api/deezer.dart';
import 'api/download.dart';
import 'api/player.dart';
import 'settings.dart';
import 'ui/home_screen.dart';
import 'ui/player_bar.dart';

Function updateTheme;
Function logOut;
GlobalKey<NavigatorState> mainNavigatorKey = GlobalKey<NavigatorState>();
GlobalKey<NavigatorState> navigatorKey;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //Initialize globals
  settings = await Settings().loadSettings();
  await downloadManager.init();
  cache = await Cache.load();

  //Do on BG
  playerHelper.authorizeLastFM();

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
    _updateTheme();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _updateTheme() {
    setState(() {
      settings.themeData;
    });
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: settings.themeData.bottomAppBarColor,
      systemNavigationBarIconBrightness: settings.isDark? Brightness.light : Brightness.dark
    ));
  }

  Locale _locale() {
    if (settings.language == null || settings.language.split('_').length < 2) return null;
    return Locale(settings.language.split('_')[0], settings.language.split('_')[1]);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freezer',
      theme: settings.themeData,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedLocales,
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
        child: I18n(
          initialLocale: _locale(),
          child: LoginMainWrapper(),
        ),
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
      deezerAPI.authorize().then((b) async {
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
      return LoginWidget(
        callback: () => setState(() => {}),
      );
    return MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin{
  List<Widget> _screens = [HomeScreen(), SearchScreen(), LibraryScreen()];
  int _selected = 0;
  StreamSubscription _urlLinkStream;

  @override
  void initState() {
    navigatorKey = GlobalKey<NavigatorState>();

    //Start with parameters
    _setupUniLinks();
    _loadPreloadInfo();
    _prepareQuickActions();

    super.initState();
  }

  void _prepareQuickActions() {
    final QuickActions quickActions = QuickActions();
    quickActions.initialize((type) {
      if (type != null)
        _startPreload(type);
    });

    //Actions
    quickActions.setShortcutItems([
      ShortcutItem(type: 'favorites', localizedTitle: 'Favorites'.i18n, icon: 'ic_favorites'),
      ShortcutItem(type: 'flow', localizedTitle: 'Flow'.i18n, icon: 'ic_flow'),

    ]);
  }

  void _startPreload(String type) async {
    await deezerAPI.authorize();
    if (type == 'flow') {
      await playerHelper.playFromSmartTrackList(SmartTrackList(id: 'flow'));
      return;
    }
    if (type == 'favorites') {
      Playlist p = await deezerAPI.fullPlaylist(deezerAPI.favoritesPlaylistId);
      playerHelper.playFromPlaylist(p, p.tracks[0].id);
    }
  }

  void _loadPreloadInfo() async {
    String info = await DownloadManager.platform.invokeMethod('getPreloadInfo');
    if (info != null) {
      //Used if started from android auto
      await deezerAPI.authorize();
      _startPreload(info);
    }
  }

  @override
  void dispose() {
    if (_urlLinkStream != null)
      _urlLinkStream.cancel();
    super.dispose();
  }

  void _setupUniLinks() async {
    //Listen to URLs
    _urlLinkStream = getUriLinksStream().listen((Uri uri) {
      openScreenByURL(context, uri.toString());
    }, onError: (err) {});
    //Get initial link on cold start
    try {
      String link = await getInitialLink();
      if (link != null && link.length > 4)
        openScreenByURL(context, link);
    } catch (e) {}
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
                  icon: Icon(Icons.home), title: Text('Home'.i18n)),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                title: Text('Search'.i18n),
              ),
              BottomNavigationBarItem(
                  icon: Icon(Icons.library_music), title: Text('Library'.i18n))
            ],
          )
        ],
      ),
      body: AudioServiceWidget(
        child: CustomNavigator(
          navigatorKey: navigatorKey,
          home: _screens[_selected],
          pageRoute: PageRoutes.materialPageRoute,
        ),
      ));
  }
}
