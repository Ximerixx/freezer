import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'dart:io';
import 'dart:convert';

ImagesDatabase imagesDatabase = ImagesDatabase();

class ImagesDatabase {

  /*
    images.db:
    Table: images
    Fields:
      id - id
      name - md5 hash of url. also filename
      url - url
      permanent - 0/1 - if image is cached or offline
  */


  Database db;
  String imagesPath;

  //Prepare database
  Future init() async {
    String dir = await getDatabasesPath();
    String path = p.join(dir, 'images.db');
    db = await openDatabase(
      path,
      version: 1,
      singleInstance: false,
      onCreate: (Database db, int version) async {
        //Create table on db created
        await db.execute('CREATE TABLE images (id INTEGER PRIMARY KEY, name TEXT, url TEXT, permanent INTEGER)');
      }
    );
    //Prepare folders
    imagesPath = p.join((await getApplicationDocumentsDirectory()).path, 'images/');
    Directory imagesDir = Directory(imagesPath);
    await imagesDir.create(recursive: true);
  }

  String getPath(String name) {
    return p.join(imagesPath, name);
  }

  //Get image url/path, cache it
  Future<String> getImage(String url, {bool permanent = false}) async {
    //Already file
    if (!url.startsWith('http')) {
      url = url.replaceFirst('file://', '');
      if (!permanent) return url;
      //Update in db to permanent
      String name = p.basenameWithoutExtension(url);
      await db.rawUpdate('UPDATE images SET permanent == 1 WHERE name == ?', [name]);
    }
    //Filename = md5 hash
    String hash = md5.convert(utf8.encode(url)).toString();
    List<Map> results = await db.rawQuery('SELECT * FROM images WHERE name == ?', [hash]);
    String path = getPath(hash);
    if (results.length > 0) {
      //Image in database
      return path;
    }
    //Save image
    Dio dio = Dio();
    try {
      await dio.download(url, path);
      await db.insert('images', {'url': url, 'name': hash, 'permanent': permanent?1:0});
      return path;
    } catch (e) {
      return null;
    }
  }

  Future<PaletteGenerator> getPaletteGenerator(String url) async {
    String path = await getImage(url);
    //Get image provider
    ImageProvider provider = AssetImage('assets/cover.jpg');
    if (path != null) {
      provider = FileImage(File(path));
    }
    PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(provider);
    return paletteGenerator;
  }

  //Get primary color from album art
  Future<Color> getPrimaryColor(String url) async {
    PaletteGenerator paletteGenerator = await getPaletteGenerator(url);
    return paletteGenerator.colors.first;
  }

  //Check if is dark
  Future<bool> isDark(String url) async {
    PaletteGenerator paletteGenerator = await getPaletteGenerator(url);
    return paletteGenerator.colors.first.computeLuminance() > 0.5 ? false : true;
  }


}

class CachedImage extends StatefulWidget {

  final String url;
  final double width;
  final double height;
  final bool circular;

  const CachedImage({Key key, this.url, this.height, this.width, this.circular = false}): super(key: key);

  @override
  _CachedImageState createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {

  final ImageProvider _placeholder = AssetImage('assets/cover.jpg');
  ImageProvider _image = AssetImage('assets/cover.jpg');
  double _opacity = 0.0;
  bool _disposed = false;

  Future<ImageProvider> _getImage() async {
    //Image already path
    if (!widget.url.startsWith('http')) {
      //Remove file://, if used in audio_service
      if (widget.url.startsWith('/')) return FileImage(File(widget.url));
      return FileImage(File(widget.url.replaceFirst('file://', '')));
    }
    //Load image from db
    String path = await imagesDatabase.getImage(widget.url);
    if (path == null) return _placeholder;
    return FileImage(File(path));
  }

  //Load image and fade
  void _load() async {
    ImageProvider image = await _getImage();
    if (_disposed) return;
    setState(() {
      _image = image;
      _opacity = 1.0;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void initState() {
    _load();
    super.initState();
  }

  @override
  void didUpdateWidget(CachedImage oldWidget) {
    _load();
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.circular ?
        CircleAvatar(
          radius: (widget.width??widget.height),
          backgroundImage: _placeholder,
        ):
        Image(
          image: _placeholder,
          height: widget.height,
          width: widget.width,
        ),
        AnimatedOpacity(
          duration: Duration(milliseconds: 250),
          opacity: _opacity,
          child: widget.circular ?
          CircleAvatar(
            radius: (widget.width??widget.height),
            backgroundImage: _image,
          ):
          Image(
            image: _image,
            height: widget.height,
            width: widget.width,
          ),
        )
      ],
    );
  }

}


