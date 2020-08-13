import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:freezer/api/deezer.dart';
import 'package:freezer/api/download.dart';
import 'package:freezer/ui/details_screens.dart';
import 'package:freezer/ui/error.dart';

import '../api/definitions.dart';
import '../api/player.dart';
import 'cached_image.dart';

class MenuSheet {

  BuildContext context;

  MenuSheet(this.context);

  //===================
  // DEFAULT
  //===================

  void show(List<Widget> options) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (BuildContext context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (MediaQuery.of(context).orientation == Orientation.landscape)?220:350,
          ),
          child: SingleChildScrollView(
            child: Column(
                children: options
            ),
          ),
        );
      }
    );
  }

  //===================
  // TRACK
  //===================

  void showWithTrack(Track track, List<Widget> options) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(height: 16.0,),
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                CachedImage(
                  url: track.albumArt.full,
                  height: 128,
                  width: 128,
                ),
                Container(
                  width: 240.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        track.title,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      Text(
                        track.artistString,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 20.0
                        ),
                      ),
                      Container(height: 8.0,),
                      Text(
                        track.album.title,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        track.durationString
                      )
                    ],
                  ),
                ),
              ],
            ),
            Container(height: 16.0,),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (MediaQuery.of(context).orientation == Orientation.landscape)?220:350,
              ),
              child: SingleChildScrollView(
                child: Column(
                    children: options
                ),
              ),
            )
          ],
        );
      }
    );
  }

  //Default track options
  void defaultTrackMenu(Track track, {List<Widget> options = const [], Function onRemove}) {
    showWithTrack(track, [
      addToQueueNext(track),
      addToQueue(track),
      (track.favorite??false)?removeFavoriteTrack(track, onUpdate: onRemove):addTrackFavorite(track),
      addToPlaylist(track),
      downloadTrack(track),
      showAlbum(track.album),
      ...List.generate(track.artists.length, (i) => showArtist(track.artists[i])),
      ...options
    ]);
  }

  //===================
  // TRACK OPTIONS
  //===================

  Widget addToQueueNext(Track t) => ListTile(
      title: Text('Play next'),
      leading: Icon(Icons.playlist_play),
      onTap: () async {
        //-1 = next
        await AudioService.addQueueItemAt(t.toMediaItem(), -1);
        _close();
      });

  Widget addToQueue(Track t) => ListTile(
      title: Text('Add to queue'),
      leading: Icon(Icons.playlist_add),
      onTap: () async {
        await AudioService.addQueueItem(t.toMediaItem());
        _close();
      }
  );

  Widget addTrackFavorite(Track t) => ListTile(
      title: Text('Add track to favorites'),
      leading: Icon(Icons.favorite),
      onTap: () async {
        await deezerAPI.addFavoriteTrack(t.id);
        //Make track offline, if favorites are offline
        Playlist p = Playlist(id: deezerAPI.favoritesPlaylistId);
        if (await downloadManager.checkOffline(playlist: p)) {
          downloadManager.addOfflinePlaylist(p);
        }
        Fluttertoast.showToast(
            msg: 'Added to library!',
            gravity: ToastGravity.BOTTOM,
            toastLength: Toast.LENGTH_SHORT
        );
        _close();
      }
  );

  Widget downloadTrack(Track t) => ListTile(
    title: Text('Download'),
    leading: Icon(Icons.file_download),
    onTap: () async {
      await downloadManager.addOfflineTrack(t, private: false);
      _close();
    },
  );

  Widget addToPlaylist(Track t) => ListTile(
    title: Text('Add to playlist'),
    leading: Icon(Icons.playlist_add),
    onTap: () async {

      Playlist p;

      //Show dialog to pick playlist
      await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Select playlist'),
              content: FutureBuilder(
                future: deezerAPI.getPlaylists(),
                builder: (context, snapshot) {

                  if (snapshot.hasError) SizedBox(
                    height: 100,
                    child: ErrorScreen(),
                  );
                  if (snapshot.connectionState != ConnectionState.done) return SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator(),),
                  );

                  List<Playlist> playlists = snapshot.data;
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...List.generate(playlists.length, (i) => ListTile(
                          title: Text(playlists[i].title),
                          leading: CachedImage(
                            url: playlists[i].image.thumb,
                          ),
                          onTap: () {
                            p = playlists[i];
                            Navigator.of(context).pop();
                          },
                        )),
                        ListTile(
                          title: Text('Create new playlist'),
                          leading: Icon(Icons.add),
                          onTap: () {
                            Navigator.of(context).pop();
                            showDialog(
                              context: context,
                              builder: (context) => CreatePlaylistDialog(tracks: [t],)
                            );
                          },
                        )
                      ]
                    ),
                  );
                },
              ),
            );
          }
      );
      //Add to playlist, show toast
      if (p != null) {
        await deezerAPI.addToPlaylist(t.id, p.id);
        //Update the playlist if offline
        if (await downloadManager.checkOffline(playlist: p)) {
          downloadManager.addOfflinePlaylist(p);
        }
        Fluttertoast.showToast(
          msg: "Track added to ${p.title}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }

      _close();
    },
  );

  Widget removeFromPlaylist(Track t, Playlist p) => ListTile(
    title: Text('Remove from playlist'),
    leading: Icon(Icons.delete),
    onTap: () async {
      await deezerAPI.removeFromPlaylist(t.id, p.id);
      Fluttertoast.showToast(
        msg: 'Track removed from ${p.title}',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      _close();
    },
  );

  Widget removeFavoriteTrack(Track t, {onUpdate}) => ListTile(
    title: Text('Remove favorite'),
    leading: Icon(Icons.delete),
    onTap: () async {
      await deezerAPI.removeFavorite(t.id);
      //Check if favorites playlist is offline, update it
      Playlist p = Playlist(id: deezerAPI.favoritesPlaylistId);
      if (await downloadManager.checkOffline(playlist: p)) {
        await downloadManager.addOfflinePlaylist(p);
      }
      Fluttertoast.showToast(
        msg: 'Track removed from library',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM
      );
      onUpdate();
      _close();
    },
  );

  //Redirect to artist page (ie from track)
  Widget showArtist(Artist a) => ListTile(
    title: Text(
      'Go to ${a.name}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    leading: Icon(Icons.recent_actors),
    onTap: () {
      _close();
      Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => ArtistDetails(a))
      );
    },
  );

  Widget showAlbum(Album a) => ListTile(
    title: Text(
      'Go to ${a.title}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    leading: Icon(Icons.album),
    onTap: () {
      _close();
      Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => AlbumDetails(a))
      );
    },
  );


  //===================
  // ALBUM
  //===================

  //Default album options
  void defaultAlbumMenu(Album album, {List<Widget> options = const [], Function onRemove}) {
    show([
      album.library?removeAlbum(album, onRemove: onRemove):libraryAlbum(album),
      downloadAlbum(album),
      offlineAlbum(album),
      ...options
    ]);
  }

  //===================
  // ALBUM OPTIONS
  //===================

  Widget downloadAlbum(Album a) => ListTile(
      title: Text('Download'),
      leading: Icon(Icons.file_download),
      onTap: () async {
        await downloadManager.addOfflineAlbum(a, private: false);
        _close();
      }
  );

  Widget offlineAlbum(Album a) => ListTile(
    title: Text('Make offline'),
    leading: Icon(Icons.offline_pin),
    onTap: () async {
      await deezerAPI.addFavoriteAlbum(a.id);
      await downloadManager.addOfflineAlbum(a, private: true);
      _close();
    },
  );

  Widget libraryAlbum(Album a) => ListTile(
    title: Text('Add to library'),
    leading: Icon(Icons.library_music),
    onTap: () async {
      await deezerAPI.addFavoriteAlbum(a.id);
      Fluttertoast.showToast(
          msg: 'Added to library',
          gravity: ToastGravity.BOTTOM
      );
      _close();
    },
  );

  //Remove album from favorites
  Widget removeAlbum(Album a, {Function onRemove}) => ListTile(
    title: Text('Remove album'),
    leading: Icon(Icons.delete),
    onTap: () async {
      await deezerAPI.removeAlbum(a.id);
      await downloadManager.removeOfflineAlbum(a.id);
      Fluttertoast.showToast(
        msg: 'Album removed',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      if (onRemove != null) onRemove();
      _close();
    },
  );

  //===================
  // ARTIST
  //===================

  void defaultArtistMenu(Artist artist, {List<Widget> options = const [], Function onRemove}) {
    show([
      artist.library?removeArtist(artist, onRemove: onRemove):favoriteArtist(artist),
      ...options
    ]);
  }

  //===================
  // ARTIST OPTIONS
  //===================

  Widget removeArtist(Artist a, {Function onRemove}) => ListTile(
    title: Text('Remove from favorites'),
    leading: Icon(Icons.delete),
    onTap: () async {
      await deezerAPI.removeArtist(a.id);
      Fluttertoast.showToast(
          msg: 'Artist removed from library',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM
      );
      if (onRemove != null) onRemove();
      _close();
    },
  );

  Widget favoriteArtist(Artist a) => ListTile(
    title: Text('Add to favorites'),
    leading: Icon(Icons.favorite),
    onTap: () async {
      await deezerAPI.addFavoriteArtist(a.id);
      Fluttertoast.showToast(
          msg: 'Added to library',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM
      );
      _close();
    },
  );

  //===================
  // PLAYLIST
  //===================

  void defaultPlaylistMenu(Playlist playlist, {List<Widget> options = const [], Function onRemove}) {
    show([
      playlist.library?removePlaylistLibrary(playlist, onRemove: onRemove):addPlaylistLibrary(playlist),
      addPlaylistOffline(playlist),
      downloadPlaylist(playlist),
      ...options
    ]);
  }

  //===================
  // PLAYLIST OPTIONS
  //===================

  Widget removePlaylistLibrary(Playlist p, {Function onRemove}) => ListTile(
    title: Text('Remove from library'),
    leading: Icon(Icons.delete),
    onTap: () async {
      if (p.user.id.trim() == deezerAPI.userId) {
        //Delete playlist if own
        await deezerAPI.deletePlaylist(p.id);
      } else {
        //Just remove from library
        await deezerAPI.removePlaylist(p.id);
      }
      downloadManager.removeOfflinePlaylist(p.id);
      if (onRemove != null) onRemove();
      _close();
    },
  );

  Widget addPlaylistLibrary(Playlist p) => ListTile(
    title: Text('Add playlist to library'),
    leading: Icon(Icons.favorite),
    onTap: () async {
      await deezerAPI.addPlaylist(p.id);
      Fluttertoast.showToast(
          msg: 'Added playlist to library',
          gravity: ToastGravity.BOTTOM
      );
      _close();
    },
  );

  Widget addPlaylistOffline(Playlist p) => ListTile(
    title: Text('Make playlist offline'),
    leading: Icon(Icons.offline_pin),
    onTap: () async {
      //Add to library
      await deezerAPI.addPlaylist(p.id);
      downloadManager.addOfflinePlaylist(p, private: true);
      _close();
    },
  );

  Widget downloadPlaylist(Playlist p) => ListTile(
    title: Text('Download playlist'),
    leading: Icon(Icons.file_download),
    onTap: () async {
      downloadManager.addOfflinePlaylist(p, private: false);
      _close();
    },
  );


  //===================
  // OTHER
  //===================

  //Create playlist
  void createPlaylist() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CreatePlaylistDialog();
      }
    );
  }


  void _close() => Navigator.of(context).pop();
}


class CreatePlaylistDialog extends StatefulWidget {

  final List<Track> tracks;
  CreatePlaylistDialog({this.tracks, Key key}): super(key: key);

  @override
  _CreatePlaylistDialogState createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {

  int _playlistType = 1;
  String _title = '';
  String _description = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create playlist'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            decoration: InputDecoration(
              labelText: 'Title'
            ),
            onChanged: (String s) => _title = s,
          ),
          TextField(
            onChanged: (String s) => _description = s,
            decoration: InputDecoration(
                labelText: 'Description'
            ),
          ),
          Container(height: 4.0,),
          DropdownButton<int>(
            value: _playlistType,
            onChanged: (int v) {
              setState(() => _playlistType = v);
            },
            items: [
              DropdownMenuItem<int>(
                value: 1,
                child: Text('Private'),
              ),
              DropdownMenuItem<int>(
                value: 2,
                child: Text('Collaborative'),
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        FlatButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FlatButton(
          child: Text('Create'),
          onPressed: () async {
            List<String> tracks = [];
            if (widget.tracks != null) {
              tracks = widget.tracks.map<String>((t) => t.id).toList();
            }
            await deezerAPI.createPlaylist(
              _title,
              status: _playlistType,
              description: _description,
              trackIds: tracks
            );
            Fluttertoast.showToast(
              msg: 'Playlist created!',
              gravity: ToastGravity.BOTTOM
            );
            Navigator.of(context).pop();
          },
        )
      ],
    );
  }
}
