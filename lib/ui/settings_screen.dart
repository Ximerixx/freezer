import 'package:audio_service/audio_service.dart';
import 'package:country_pickers/country.dart';
import 'package:country_pickers/country_picker_dialog.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:freezer/api/deezer.dart';
import 'package:freezer/ui/error.dart';
import 'package:i18n_extension/i18n_widget.dart';
import 'package:language_pickers/language_pickers.dart';
import 'package:language_pickers/languages.dart';
import 'package:package_info/package_info.dart';
import 'package:path_provider_ex/path_provider_ex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:freezer/translations.i18n.dart';
import 'package:clipboard/clipboard.dart';

import '../settings.dart';
import '../main.dart';

import 'dart:io';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  String _about = '';

  @override
  void initState() {
    //Load about text
    PackageInfo.fromPlatform().then((PackageInfo info) {
      setState(() {
        _about = '${info.appName}';
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings'.i18n),),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text('General'.i18n),
            leading: Icon(Icons.settings),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => GeneralSettings()
            )),
          ),
          ListTile(
            title: Text('Appearance'.i18n),
            leading: Icon(Icons.color_lens),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AppearanceSettings())
            ),
          ),
          ListTile(
            title: Text('Quality'.i18n),
            leading: Icon(Icons.high_quality),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => QualitySettings())
            ),
          ),
          ListTile(
            title: Text('Deezer'.i18n),
            leading: Icon(Icons.equalizer),
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => DeezerSettings()
            )),
          ),
          //Language select
          ListTile(
            title: Text('Language'.i18n),
            leading: Icon(Icons.language),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => LanguagePickerDialog(
                  titlePadding: EdgeInsets.all(8.0),
                  title: Text('Select language'.i18n),
                  isSearchable: false,
                  languagesList: supportedLocales.map<Map<String, String>>((l) {
                    Map _lang = defaultLanguagesList.firstWhere((lang) => lang['isoCode'] == l.languageCode);
                    _lang['name'] = _lang['name'] + ' (${l.toString()})';
                    return _lang;
                  }).toList(),
                  onValuePicked: (Language l) async {
                    setState(()  {
                      Locale locale = supportedLocales.firstWhere((_l) => _l.languageCode == l.isoCode);
                      settings.language = locale.toString();
                    });
                    await settings.save();
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text('Language'.i18n),
                          content: Text('Language changed, please restart Freezer to apply!'.i18n),
                          actions: [
                            FlatButton(
                              child: Text('OK'),
                              onPressed: () => Navigator.of(context).pop(),
                            )
                          ],
                        );
                      }
                    );
                  },
                )
              );
            },
          ),
          Divider(),
          Text(
            _about,
            textAlign: TextAlign.center,
          )
        ],
      ),
    );
  }
}

class AppearanceSettings extends StatefulWidget {
  @override
  _AppearanceSettingsState createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<AppearanceSettings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Appearance'.i18n),),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text('Theme'.i18n),
            subtitle: Text('Currently'.i18n + ': ${settings.theme.toString().split('.').last}'),
            leading: Icon(Icons.color_lens),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return SimpleDialog(
                    title: Text('Select theme'.i18n),
                    children: <Widget>[
                      SimpleDialogOption(
                        child: Text('Light (default)'.i18n),
                        onPressed: () {
                          setState(() => settings.theme = Themes.Light);
                          settings.save();
                          updateTheme();
                          Navigator.of(context).pop();
                        },
                      ),
                      SimpleDialogOption(
                        child: Text('Dark'.i18n),
                        onPressed: () {
                          setState(() => settings.theme = Themes.Dark);
                          settings.save();
                          updateTheme();
                          Navigator.of(context).pop();
                        },
                      ),
                      SimpleDialogOption(
                        child: Text('Black (AMOLED)'.i18n),
                        onPressed: () {
                          setState(() => settings.theme = Themes.Black);
                          settings.save();
                          updateTheme();
                          Navigator.of(context).pop();
                        },
                      ),
                      SimpleDialogOption(
                        child: Text('Deezer (Dark)'.i18n),
                        onPressed: () {
                          setState(() => settings.theme = Themes.Deezer);
                          settings.save();
                          updateTheme();
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                }
              );
            },
          ),
          ListTile(
            title: Text('Primary color'.i18n),
            leading: Icon(Icons.format_paint),
            subtitle: Text(
              'Selected color'.i18n,
              style: TextStyle(
                color: settings.primaryColor
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text('Primary color'.i18n),
                    content: Container(
                      height: 200,
                      child: MaterialColorPicker(
                        allowShades: false,
                        selectedColor: settings.primaryColor,
                        onMainColorChange: (ColorSwatch color) {
                          setState(() {
                            settings.primaryColor = color;
                          });
                          settings.save();
                          updateTheme();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  );
                }
              );
            },
          ),
          ListTile(
            title: Text('Use album art primary color'.i18n),
            subtitle: Text('Warning: might be buggy'.i18n),
            leading: Switch(
              value: settings.useArtColor,
              onChanged: (v) => setState(() => settings.updateUseArtColor(v)),
            ),
          )
        ],
      ),
    );
  }
}


class QualitySettings extends StatefulWidget {
  @override
  _QualitySettingsState createState() => _QualitySettingsState();
}

class _QualitySettingsState extends State<QualitySettings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Quality'.i18n),),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text('Mobile streaming'.i18n),
            leading: Icon(Icons.network_cell),
          ),
          QualityPicker('mobile'),
          Divider(),
          ListTile(
            title: Text('Wifi streaming'.i18n),
            leading: Icon(Icons.network_wifi),
          ),
          QualityPicker('wifi'),
          Divider(),
          ListTile(
            title: Text('Offline'.i18n),
            leading: Icon(Icons.offline_pin),
          ),
          QualityPicker('offline'),
          Divider(),
          ListTile(
            title: Text('External downloads'.i18n),
            leading: Icon(Icons.file_download),
          ),
          QualityPicker('download'),
        ],
      ),
    );
  }
}

class QualityPicker extends StatefulWidget {

  final String field;
  QualityPicker(this.field, {Key key}): super(key: key);

  @override
  _QualityPickerState createState() => _QualityPickerState();
}

class _QualityPickerState extends State<QualityPicker> {

  AudioQuality _quality;

  @override
  void initState() {
    _getQuality();
    super.initState();
  }

  //Get current quality
  void _getQuality() {
    switch (widget.field) {
      case 'mobile':
        _quality = settings.mobileQuality; break;
      case 'wifi':
        _quality = settings.wifiQuality; break;
      case 'download':
        _quality = settings.downloadQuality; break;
      case 'offline':
        _quality = settings.offlineQuality; break;
    }
  }

  //Update quality in settings
  void _updateQuality(AudioQuality q) {
    setState(() {
      _quality = q;
    });
    switch (widget.field) {
      case 'mobile':
        settings.mobileQuality = _quality;
        settings.updateAudioServiceQuality();
        break;
      case 'wifi':
        settings.wifiQuality = _quality;
        settings.updateAudioServiceQuality();
        break;
      case 'download':
        settings.downloadQuality = _quality; break;
      case 'offline':
        settings.offlineQuality = _quality; break;
    }
    settings.updateAudioServiceQuality();
  }

  @override
  void dispose() {
    //Save
    settings.updateAudioServiceQuality();
    settings.save();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ListTile(
          title: Text('MP3 128kbps'),
          leading: Radio(
            groupValue: _quality,
            value: AudioQuality.MP3_128,
            onChanged: (q) => _updateQuality(q),
          ),
        ),
        ListTile(
          title: Text('MP3 320kbps'),
          leading: Radio(
            groupValue: _quality,
            value: AudioQuality.MP3_320,
            onChanged: (q) => _updateQuality(q),
          ),
        ),
        ListTile(
          title: Text('FLAC'),
          leading: Radio(
            groupValue: _quality,
            value: AudioQuality.FLAC,
            onChanged: (q) => _updateQuality(q),
          ),
        ),
      ],
    );
  }
}

class DeezerSettings extends StatefulWidget {
  @override
  _DeezerSettingsState createState() => _DeezerSettingsState();
}

class _DeezerSettingsState extends State<DeezerSettings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Deezer'.i18n),),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text('Content language'.i18n),
            subtitle: Text('Not app language, used in headers. Now'.i18n + ': ${settings.deezerLanguage}'),
            leading: Icon(Icons.language),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => LanguagePickerDialog(
                  titlePadding: EdgeInsets.all(8.0),
                  isSearchable: true,
                  title: Text('Select language'.i18n),
                  onValuePicked: (Language language) {
                    setState(() => settings.deezerLanguage = language.isoCode);
                    settings.save();
                  },
                )
              );
            },
          ),
          ListTile(
            title: Text('Content country'.i18n),
            subtitle: Text('Country used in headers. Now'.i18n + ': ${settings.deezerCountry}'),
            leading: Icon(Icons.vpn_lock),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => CountryPickerDialog(
                  titlePadding: EdgeInsets.all(8.0),
                  isSearchable: true,
                  onValuePicked: (Country country) {
                    setState(() => settings.deezerCountry = country.isoCode);
                    settings.save();
                  },
                )
              );
            },
          ),
          ListTile(
            title: Text('Log tracks'.i18n),
            subtitle: Text('Send track listen logs to Deezer, enable it for features like Flow to work properly'.i18n),
            leading: Checkbox(
              value: settings.logListen,
              onChanged: (bool v) {
                setState(() => settings.logListen = v);
                settings.save();
              },
            ),
          )
        ],
      ),
    );
  }
}

class GeneralSettings extends StatefulWidget {
  @override
  _GeneralSettingsState createState() => _GeneralSettingsState();
}

class _GeneralSettingsState extends State<GeneralSettings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('General'.i18n),),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text('Offline mode'.i18n),
            subtitle: Text('Will be overwritten on start.'.i18n),
            leading: Switch(
              value: settings.offlineMode,
              onChanged: (bool v) {
                if (v) {
                  setState(() => settings.offlineMode = true);
                  return;
                }
                showDialog(
                  context: context,
                  builder: (context) {
                    deezerAPI.authorize().then((v) {
                      if (v) {
                        setState(() => settings.offlineMode = false);
                      } else {
                        Fluttertoast.showToast(
                          msg: 'Error logging in, check your internet connections.'.i18n,
                          gravity: ToastGravity.BOTTOM,
                          toastLength: Toast.LENGTH_SHORT
                        );
                      }
                      Navigator.of(context).pop();
                    });
                    return AlertDialog(
                      title: Text('Logging in...'.i18n),
                      content: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          CircularProgressIndicator()
                        ],
                      )
                    );
                  }
                );
              },
            ),
          ),
          ListTile(
            title: Text('Download path'.i18n),
            leading: Icon(Icons.folder),
            subtitle: Text(settings.downloadPath),
            onTap: () async {
              //Check permissions
              if (!(await Permission.storage.request().isGranted)) return;
              //Navigate
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => DirectoryPicker(settings.downloadPath, onSelect: (String p) {
                  setState(() => settings.downloadPath = p);
                },)
              ));
            },
          ),
          ListTile(
            title: Text('Downloads naming'.i18n),
            subtitle: Text('Currently'.i18n + ': ${settings.downloadFilename}'),
            leading: Icon(Icons.text_format),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {

                  TextEditingController _controller = TextEditingController();
                  String filename = settings.downloadFilename;
                  _controller.value = _controller.value.copyWith(text: filename);
                  String _new = _controller.value.text;

                  //Dialog with filename format
                  return AlertDialog(
                    title: Text('Downloaded tracks filename'.i18n),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _controller,
                          onChanged: (String s) => _new = s,
                        ),
                        Container(height: 8.0),
                        Text(
                          'Valid variables are'.i18n + ': %artists%, %artist%, %title%, %album%, %trackNumber%, %0trackNumber%, %feats%',
                          style: TextStyle(
                            fontSize: 12.0,
                          ),
                        )
                      ],
                    ),
                    actions: [
                      FlatButton(
                        child: Text('Cancel'.i18n),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      FlatButton(
                        child: Text('Reset'.i18n),
                        onPressed: () {
                          _controller.value = _controller.value.copyWith(
                            text: '%artists% - %title%'
                          );
                          _new = '%artists% - %title%';
                        },
                      ),
                      FlatButton(
                        child: Text('Clear'.i18n),
                        onPressed: () => _controller.clear(),
                      ),
                      FlatButton(
                        child: Text('Save'.i18n),
                        onPressed: () async {
                          setState(() {
                            settings.downloadFilename = _new;
                          });
                          await settings.save();
                          Navigator.of(context).pop();
                        },
                      )
                    ],
                  );
                }
              );
            },
          ),
          ListTile(
            title: Text('Create folders for artist'.i18n),
            leading: Switch(
              value: settings.artistFolder,
              onChanged: (v) {
                setState(() => settings.artistFolder = v);
                settings.save();
              },
            ),
          ),
          ListTile(
            title: Text('Create folders for albums'.i18n),
            leading: Switch(
              value: settings.albumFolder,
              onChanged: (v) {
                setState(() => settings.albumFolder = v);
                settings.save();
              },
            ),
          ),
          ListTile(
            title: Text('Separate albums by discs'.i18n),
            leading: Switch(
              value: settings.albumDiscFolder,
              onChanged: (v) {
                setState(() => settings.albumDiscFolder = v);
                settings.save();
              },
            ),
          ),
          ListTile(
            title: Text('Overwrite already downloaded files'.i18n),
            leading: Switch(
              value: settings.overwriteDownload,
              onChanged: (v) {
                setState(() => settings.overwriteDownload = v);
                settings.save();
              },
            ),
          ),
          ListTile(
            title: Text('Copy ARL'.i18n),
            subtitle: Text('Copy userToken/ARL Cookie for use in other apps.'.i18n),
            leading: Icon(Icons.lock),
            onTap: () async {
              await FlutterClipboard.copy(settings.arl);
              await Fluttertoast.showToast(
                msg: 'Copied'.i18n,
              );
            },
          ),
          ListTile(
            title: Text('Log out'.i18n, style: TextStyle(color: Colors.red),),
            leading: Icon(Icons.exit_to_app),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text('Log out'.i18n),
                    content: Text('Due to plugin incompatibility, login using browser is unavailable without restart.'.i18n),
                    actions: <Widget>[
                      FlatButton(
                        child: Text('Cancel'.i18n),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      FlatButton(
                        child: Text('(ARL ONLY) Continue'.i18n),
                        onPressed: () {
                          logOut();
                          Navigator.of(context).pop();
                        },
                      ),
                      FlatButton(
                        child: Text('Log out & Exit'.i18n),
                        onPressed: () async {
                          try {AudioService.stop();} catch (e) {}
                          await logOut();
                          SystemNavigator.pop();
                        },
                      )
                    ],
                  );
                }
              );
            }
          )
        ],
      ),
    );
  }
}

class DirectoryPicker extends StatefulWidget {

  final String initialPath;
  final Function onSelect;
  DirectoryPicker(this.initialPath, {this.onSelect, Key key}): super(key: key);

  @override
  _DirectoryPickerState createState() => _DirectoryPickerState();
}

class _DirectoryPickerState extends State<DirectoryPicker> {

  String _path;
  String _previous;
  String _root;

  @override
  void initState() {
    _path = widget.initialPath;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pick-a-Path'.i18n),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.sd_card),
            onPressed: () {
              String path = '';
              //Chose storage
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text('Select storage'.i18n),
                    content: FutureBuilder(
                      future: PathProviderEx.getStorageInfo(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return ErrorScreen();
                        if (!snapshot.hasData) return Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              CircularProgressIndicator()
                            ],
                          ),
                        );
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            ...List.generate(snapshot.data.length, (i) {
                              StorageInfo si = snapshot.data[i];
                              return ListTile(
                                title: Text(si.rootDir),
                                leading: Icon(Icons.sd_card),
                                trailing: Text(filesize(si.availableBytes)),
                                onTap: () {
                                  setState(() {
                                    _path = si.appFilesDir;
                                    //Android 5+ blocks sd card, so this prevents going outside
                                    //app data dir, until permission request fix.
                                    _root = si.rootDir;
                                    if (i != 0) _root = si.appFilesDir;
                                  });
                                  Navigator.of(context).pop();
                                },
                              );
                            })
                          ],
                        );
                      },
                    ),
                  );
                }
              );
            }
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.done),
        onPressed: () {
          //When folder confirmed
          if (widget.onSelect != null) widget.onSelect(_path);
          Navigator.of(context).pop();
        },
      ),
      body: FutureBuilder(
        future: Directory(_path).list().toList(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {

          //On error go to last good path
          if (snapshot.hasError) Future.delayed(Duration(milliseconds: 50), () =>  setState(() => _path = _previous));
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(),);

          List<FileSystemEntity> data = snapshot.data;
          return ListView(
            children: <Widget>[
              ListTile(
                title: Text(_path),
              ),
              ListTile(
                title: Text('Go up'.i18n),
                leading: Icon(Icons.arrow_upward),
                onTap: () {
                  setState(() {
                    if (_root == _path) {
                      Fluttertoast.showToast(
                          msg: 'Permission denied'.i18n,
                          gravity: ToastGravity.BOTTOM
                      );
                      return;
                    }
                    _previous = _path;
                    _path = Directory(_path).parent.path;
                  });
                },
              ),
              ...List.generate(data.length, (i) {
                FileSystemEntity f = data[i];
                if (f is Directory) {
                  return ListTile(
                    title: Text(f.path.split('/').last),
                    leading: Icon(Icons.folder),
                    onTap: () {
                      setState(() {
                        _previous = _path;
                        _path = f.path;
                      });
                    },
                  );
                }
                return Container(height: 0, width: 0,);
              })
            ],
          );
        },
      ),
    );
  }
}
