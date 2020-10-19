import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:freezer/api/deezer.dart';
import 'package:freezer/api/definitions.dart';
import 'package:freezer/api/download.dart';
import 'package:freezer/api/spotify.dart';
import 'package:freezer/main.dart';
import 'package:freezer/settings.dart';
import 'package:freezer/ui/elements.dart';
import 'package:freezer/ui/menu.dart';
import 'package:freezer/translations.i18n.dart';

class ImporterScreen extends StatefulWidget {
  @override
  _ImporterScreenState createState() => _ImporterScreenState();
}

class _ImporterScreenState extends State<ImporterScreen> {

  String _url;
  bool _error = false;
  bool _loading = false;
  SpotifyPlaylist _data;

  Future _load() async {
    setState(() {
      _error = false;
      _loading = true;
    });
    try {
      String uri = spotify.parseUrl(_url);

      //Error/NonPlaylist
      if (uri == null || uri.split(':')[1] != 'playlist') {
        throw Exception();
      }
      //Load
      SpotifyPlaylist data = await spotify.playlist(uri);
      setState(() => _data = data);
      return;

    } catch (e, st) {
      print('$e, $st');
      setState(() {
        _error = true;
        _loading = false;
      });
      return;
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Importer'.i18n),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text('Currently supporting only Spotify, with 100 tracks limit'.i18n),
            subtitle: Text('Due to API limitations'.i18n),
            leading: Icon(
              Icons.warning,
              color: Colors.deepOrangeAccent,
            ),
          ),
          FreezerDivider(),
          Container(height: 16.0,),
          Text(
            'Enter your playlist link below'.i18n,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.0
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    onChanged: (String s) => _url = s,
                    onSubmitted: (String s) {
                      _url = s;
                      _load();
                    },
                    decoration: InputDecoration(
                      hintText: 'URL'
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => _load(),
                )
              ],
            ),
          ),
          Container(height: 8.0,),

          if (_data == null && _loading)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CircularProgressIndicator()
              ],
            ),
          if (_error)
            ListTile(
              title: Text('Error loading URL!'.i18n),
              leading: Icon(Icons.error, color: Colors.red,),
            ),
          if (_data != null)
            ImporterWidget(_data)
        ],
      ),
    );
  }
}

class ImporterWidget extends StatefulWidget {
  
  final SpotifyPlaylist playlist;
  ImporterWidget(this.playlist, {Key key}): super(key: key);
  
  @override
  _ImporterWidgetState createState() => _ImporterWidgetState();
}

class _ImporterWidgetState extends State<ImporterWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        FreezerDivider(),
        ListTile(
          title: Text(widget.playlist.name),
          subtitle: Text(widget.playlist.description),
          //Default image
          leading: Image.network(widget.playlist.image??'http://cdn-images.deezer.com/images/cover//256x256-000000-80-0-0.jpg'),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            RaisedButton(
              child: Text('Convert'.i18n),
              color: Theme.of(context).primaryColor,
              onPressed: () {
                spotify.convertPlaylist(widget.playlist);
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (context) => CurrentlyImportingScreen()
                ));
              },
            ),
            RaisedButton(
              child: Text('Download only'.i18n),
              color: Theme.of(context).primaryColor,
              onPressed: () async {
                //Ask for quality
                AudioQuality quality;
                if (settings.downloadQuality == AudioQuality.ASK) {
                  quality = await downloadManager.qualitySelect(context);
                  if (quality == null) return;
                }

                spotify.convertPlaylist(widget.playlist, downloadOnly: true, context: context, quality: quality);
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (context) => CurrentlyImportingScreen()
                ));
              },
            ),
          ],
        ),
        ...List.generate(widget.playlist.tracks.length, (i) {
          SpotifyTrack t = widget.playlist.tracks[i];
          return ListTile(
            title: Text(
              t.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              t.artists,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        })
      ],
    );
  }
}

class CurrentlyImportingScreen extends StatelessWidget {

  Widget _stateIcon(TrackImportState s) {
    switch (s) {
      case TrackImportState.ERROR:
        return Icon(Icons.error, color: Colors.red,);
      case TrackImportState.OK:
        return Icon(Icons.done, color: Colors.green);
      default:
        return Container(width: 0, height: 0);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Importing...'.i18n),
      body: StreamBuilder(
        stream: spotify.importingStream.stream,
        builder: (context, snapshot) {

          //If not in progress
          if (spotify.importingSpotifyPlaylist == null || spotify.importingSpotifyPlaylist.tracks == null || spotify.doneImporting == null)
            return Center(child: CircularProgressIndicator(),);
          if (spotify.doneImporting) spotify.doneImporting = null;

          //Cont OK, error, total
          int ok = spotify.importingSpotifyPlaylist.tracks.where((t) => t.state == TrackImportState.OK).length;
          int err = spotify.importingSpotifyPlaylist.tracks.where((t) => t.state == TrackImportState.ERROR).length;
          int count = spotify.importingSpotifyPlaylist.tracks.length;

          return ListView(
            children: <Widget>[
              if (!(spotify.doneImporting??true)) Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    CircularProgressIndicator()
                  ],
                ),
              ),
              Container(
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.import_export, size: 24.0,),
                        Container(width: 4.0,),
                        Text('${ok+err}/$count', style: TextStyle(fontSize: 24.0),)
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.done, size: 24.0,),
                        Container(width: 4.0,),
                        Text('$ok', style: TextStyle(fontSize: 24.0),)
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.error, size: 24.0,),
                        Container(width: 4.0,),
                        Text('$err', style: TextStyle(fontSize: 24.0),),
                      ],
                    ),
                    if (snapshot.data != null)
                      FlatButton(
                        child: Text('Playlist menu'.i18n),
                        onPressed: () async {
                          Playlist p = await deezerAPI.playlist(snapshot.data);
                          p.library = true;
                          MenuSheet m = MenuSheet(context);
                          m.defaultPlaylistMenu(p);
                        },
                      )
                  ],
                ),
              ),
              Container(height: 8.0),
              FreezerDivider(),
              ...List.generate(spotify.importingSpotifyPlaylist.tracks.length, (i) {
                SpotifyTrack t = spotify.importingSpotifyPlaylist.tracks[i];
                return ListTile(
                  title: Text(t.title),
                  subtitle: Text(t.artists),
                  leading: _stateIcon(t.state),
                );
              })
            ],
          );
        },
      ),
    );
  }
}
