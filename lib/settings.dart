import 'package:audio_service/audio_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:freezer/api/download.dart';
import 'package:freezer/main.dart';
import 'package:freezer/ui/cached_image.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ext_storage/ext_storage.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';

import 'dart:io';
import 'dart:convert';
import 'dart:async';

part 'settings.g.dart';

Settings settings;

@JsonSerializable()
class Settings {

  //Language
  @JsonKey(defaultValue: null)
  String language;

  //Account
  String arl;
  @JsonKey(ignore: true)
  bool offlineMode = false;

  //Quality
  @JsonKey(defaultValue: AudioQuality.MP3_320)
  AudioQuality wifiQuality;
  @JsonKey(defaultValue: AudioQuality.MP3_128)
  AudioQuality mobileQuality;
  @JsonKey(defaultValue: AudioQuality.FLAC)
  AudioQuality offlineQuality;
  @JsonKey(defaultValue: AudioQuality.FLAC)
  AudioQuality downloadQuality;

  //Download options
  String downloadPath;

  @JsonKey(defaultValue: "%artists% - %title%")
  String downloadFilename;
  @JsonKey(defaultValue: true)
  bool albumFolder;
  @JsonKey(defaultValue: true)
  bool artistFolder;
  @JsonKey(defaultValue: false)
  bool albumDiscFolder;
  @JsonKey(defaultValue: false)
  bool overwriteDownload;
  @JsonKey(defaultValue: 2)
  int downloadThreads;
  @JsonKey(defaultValue: false)
  bool playlistFolder;
  @JsonKey(defaultValue: true)
  bool downloadLyrics;
  @JsonKey(defaultValue: false)
  bool trackCover;
  @JsonKey(defaultValue: true)
  bool albumCover;
  @JsonKey(defaultValue: false)
  bool nomediaFiles;

  //Appearance
  @JsonKey(defaultValue: Themes.Dark)
  Themes theme;
  @JsonKey(defaultValue: false)
  bool useSystemTheme;

  //Colors
  @JsonKey(toJson: _colorToJson, fromJson: _colorFromJson)
  Color primaryColor = Colors.blue;

  static _colorToJson(Color c) => c.value;
  static _colorFromJson(int v) => Color(v??Colors.blue.value);

  @JsonKey(defaultValue: false)
  bool useArtColor = false;
  StreamSubscription _useArtColorSub;

  //Deezer
  @JsonKey(defaultValue: 'en')
  String deezerLanguage;
  @JsonKey(defaultValue: 'US')
  String deezerCountry;
  @JsonKey(defaultValue: false)
  bool logListen;
  @JsonKey(defaultValue: null)
  String proxyAddress;

  Settings({this.downloadPath, this.arl});

  ThemeData get themeData {
    //System theme
    if (useSystemTheme) {
      if (SchedulerBinding.instance.window.platformBrightness == Brightness.light) {
        return _themeData[Themes.Light];
      } else {
        if (theme == Themes.Light) return _themeData[Themes.Dark];
        return _themeData[theme];
      }
    }
    //Theme
    return _themeData[theme]??ThemeData();
  }

  //JSON to forward into download service
  Map getServiceSettings() {
    return {
      "downloadThreads": downloadThreads,
      "overwriteDownload": overwriteDownload,
      "downloadLyrics": downloadLyrics,
      "trackCover": trackCover,
      "arl": arl,
      "albumCover": albumCover,
      "nomediaFiles": nomediaFiles
    };
  }

  void updateUseArtColor(bool v) {
    useArtColor = v;
    if (v) {
      //On media item change set color
      _useArtColorSub = AudioService.currentMediaItemStream.listen((event) async {
        if (event == null || event.artUri == null) return;
        this.primaryColor = await imagesDatabase.getPrimaryColor(event.artUri);
        updateTheme();
      });
    } else {
      //Cancel stream subscription
      if (_useArtColorSub != null) {
        _useArtColorSub.cancel();
        _useArtColorSub = null;
      }
    }
  }

  SliderThemeData get _sliderTheme => SliderThemeData(
    thumbColor: primaryColor,
    activeTrackColor: primaryColor,
    inactiveTrackColor: primaryColor.withOpacity(0.2)
  );

  //Load settings/init
  Future<Settings> loadSettings() async {
    String path = await getPath();
    File f = File(path);
    if (await f.exists()) {
      String data = await f.readAsString();
      return Settings.fromJson(jsonDecode(data));
    }
    Settings s = Settings.fromJson({});
    //Set default path, because async
    s.downloadPath = (await ExtStorage.getExternalStoragePublicDirectory(ExtStorage.DIRECTORY_MUSIC));
    s.save();
    return s;
  }

  Future save() async {
    File f = File(await getPath());
    await f.writeAsString(jsonEncode(this.toJson()));
    downloadManager.updateServiceSettings();
  }

  Future updateAudioServiceQuality() async {
    //Send wifi & mobile quality to audio service isolate
    await AudioService.customAction('updateQuality', {
      'mobileQuality': getQualityInt(mobileQuality),
      'wifiQuality': getQualityInt(wifiQuality)
    });
  }

  //AudioQuality to deezer int
  int getQualityInt(AudioQuality q) {
    switch (q) {
      case AudioQuality.MP3_128: return 1;
      case AudioQuality.MP3_320: return 3;
      case AudioQuality.FLAC: return 9;
    }
    return 8; //default
  }

  static const deezerBg = Color(0xFF1F1A16);
  static const font = 'MabryPro';
  Map<Themes, ThemeData> get _themeData => {
    Themes.Light: ThemeData(
      fontFamily: font,
      primaryColor: primaryColor,
      accentColor: primaryColor,
      sliderTheme: _sliderTheme,
      toggleableActiveColor: primaryColor,
      bottomAppBarColor: Color(0xfff7f7f7)
    ),
    Themes.Dark: ThemeData(
      fontFamily: font,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      accentColor: primaryColor,
      sliderTheme: _sliderTheme,
      toggleableActiveColor: primaryColor,
    ),
    Themes.Deezer: ThemeData(
      fontFamily: font,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      accentColor: primaryColor,
      sliderTheme: _sliderTheme,
      toggleableActiveColor: primaryColor,
      backgroundColor: deezerBg,
      scaffoldBackgroundColor: deezerBg,
      bottomAppBarColor: deezerBg,
      dialogBackgroundColor: deezerBg,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: deezerBg
      ),
      cardColor: deezerBg
    ),
    Themes.Black: ThemeData(
      fontFamily: font,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      accentColor: primaryColor,
      backgroundColor: Colors.black,
      scaffoldBackgroundColor: Colors.black,
      bottomAppBarColor: Colors.black,
      dialogBackgroundColor: Colors.black,
      sliderTheme: _sliderTheme,
      toggleableActiveColor: primaryColor,
      bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.black
    ))
  };

  Future<String> getPath() async => p.join((await getApplicationDocumentsDirectory()).path, 'settings.json');

  //JSON
  factory Settings.fromJson(Map<String, dynamic> json) => _$SettingsFromJson(json);
  Map<String, dynamic> toJson() => _$SettingsToJson(this);
}

enum AudioQuality {
  MP3_128,
  MP3_320,
  FLAC
}

enum Themes {
  Light,
  Dark,
  Deezer,
  Black
}