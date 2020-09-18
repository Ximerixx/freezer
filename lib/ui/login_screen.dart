import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:freezer/api/deezer.dart';
import 'package:freezer/api/player.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:freezer/translations.i18n.dart';

import '../settings.dart';
import '../api/definitions.dart';
import 'home_screen.dart';

class LoginWidget extends StatefulWidget {

  Function callback;
  LoginWidget({this.callback, Key key}): super(key: key);

  @override
  _LoginWidgetState createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {

  String _arl;

  //Initialize deezer etc
  Future _init() async {
    deezerAPI.arl = settings.arl;
    await playerHelper.start();

    //Pre-cache homepage
    if (!await HomePage().exists()) {
      await deezerAPI.authorize();
      settings.offlineMode = false;
      HomePage hp = await deezerAPI.homePage();
      await hp.save();
    }
  }
  //Call _init()
  void _start() async {
    if (settings.arl != null) {
      _init().then((_) {
        if (widget.callback != null) widget.callback();
      });
    }
  }

  @override
  void didUpdateWidget(LoginWidget oldWidget) {
    _start();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void initState() {
    _start();
    super.initState();
  }

  void errorDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Error'.i18n),
          content: Text('Error logging in! Please check your token and internet connection and try again.'.i18n),
          actions: <Widget>[
            FlatButton(
              child: Text('Dismiss'.i18n),
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ],
        );
      }
    );
  }

  void _update() async {
    setState(() => {});

    //Try logging in
    try {
      deezerAPI.arl = settings.arl;
      bool resp = await deezerAPI.authorize();
      if (resp == false) { //false, not null
        setState(() => settings.arl = null);
        errorDialog();
      }
      //On error show dialog and reset to null
    } catch (e) {
      setState(() => settings.arl = null);
      errorDialog();
    }

    await settings.save();
    _start();
  }

  @override
  Widget build(BuildContext context) {

    //If arl non null, show loading
    if (settings.arl != null)
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );

    if (settings.arl == null)
      return Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: ListView(
            children: <Widget>[
              Container(height: 16.0,),
              Text(
                'Welcome to'.i18n,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0
                ),
              ),
              FreezerTitle(),
              Container(height: 8.0,),
              Text(
                "Please login using your Deezer account.".i18n,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16.0
                ),
              ),
              Container(height: 16.0,),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: OutlineButton(
                  child: Text('Login using browser'.i18n),
                  onPressed: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => LoginBrowser(_update))
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: OutlineButton(
                  child: Text('Login using token'.i18n),
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text('Enter ARL'.i18n),
                            content: Container(
                              child: TextField(
                                onChanged: (String s) => _arl = s,
                                decoration: InputDecoration(
                                  labelText: 'Token (ARL)'.i18n
                                ),
                              ),
                            ),
                            actions: <Widget>[
                              FlatButton(
                                child: Text('Save'.i18n),
                                onPressed: () {
                                  settings.arl = _arl.trim();
                                  Navigator.of(context).pop();
                                  _update();
                                },
                              )
                            ],
                          );
                        }
                    );
                  },
                ),
              ),
              Container(height: 16.0,),
              Text(
                "If you don't have account, you can register on deezer.com for free.".i18n,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: OutlineButton(
                  child: Text('Open in browser'.i18n),
                  onPressed: () {
                    InAppBrowser.openWithSystemBrowser(url: 'https://deezer.com/register');
                  },
                ),
              ),
              Container(height: 8.0,),
              Divider(),
              Container(height: 8.0,),
              Text(
                "By using this app, you don't agree with the Deezer ToS".i18n,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0
                ),
              )
            ],
          ),
        ),
      );
    return null;
  }
}


class LoginBrowser extends StatelessWidget {

  Function updateParent;
  LoginBrowser(this.updateParent);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: Container(

            child: InAppWebView(
              initialUrl: 'https://deezer.com/login',
              onLoadStart: (InAppWebViewController controller, String url) async {
                //Parse arl from url
                if (url.startsWith('intent://deezer.page.link')) {
                  try {
                    //Parse url
                    Uri uri = Uri.parse(url);
                    //Actual url is in `link` query parameter
                    Uri linkUri = Uri.parse(uri.queryParameters['link']);
                    String arl = linkUri.queryParameters['arl'];
                    if (arl != null) {
                      settings.arl = arl;
                      Navigator.of(context).pop();
                      updateParent();
                    }
                  } catch (e) {}
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
