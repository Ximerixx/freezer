import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:freezer/main.dart';
import 'package:freezer/ui/cached_image.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ext_storage/ext_storage.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';

import 'dart:io';
import 'dart:convert';

part 'settings.g.dart';

Settings settings;

@JsonSerializable()
class Settings {

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


  //Appearance
  @JsonKey(defaultValue: Themes.Light)
  Themes theme;

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

  Settings({this.downloadPath, this.arl});

  static const deezerBg = Color(0xFF1F1A16);
  static const font = 'MabryPro';
  ThemeData get themeData {
    switch (theme??Themes.Light) {
      case Themes.Light:
        return ThemeData(
          fontFamily: font,
          primaryColor: primaryColor,
          accentColor: primaryColor,
          sliderTheme: _sliderTheme,
          toggleableActiveColor: primaryColor,
          bottomAppBarColor: Color(0xfff7f7f7)
        );
      case Themes.Dark:
        return ThemeData(
          fontFamily: font,
          brightness: Brightness.dark,
          primaryColor: primaryColor,
          accentColor: primaryColor,
          sliderTheme: _sliderTheme,
          toggleableActiveColor: primaryColor,
        );
      case Themes.Deezer:
        return ThemeData(
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
        );
      case Themes.Black:
        return ThemeData(
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
          )
        );
    }
    return ThemeData();
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