import 'dart:async';

import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:freezer/api/download.dart';
import 'package:freezer/translations.i18n.dart';

import 'cached_image.dart';

class DownloadsScreen extends StatefulWidget {
  @override
  _DownloadsScreenState createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {

  List<Download> downloads = [];
  StreamSubscription _stateSubscription;

  //Sublists
  List<Download> get downloading => downloads.where((d) => d.state == DownloadState.DOWNLOADING || d.state == DownloadState.POST).toList();
  List<Download> get queued => downloads.where((d) => d.state == DownloadState.NONE).toList();
  List<Download> get failed => downloads.where((d) => d.state == DownloadState.ERROR || d.state == DownloadState.DEEZER_ERROR).toList();
  List<Download> get finished => downloads.where((d) => d.state == DownloadState.DONE).toList();

  Future _load() async {
    //Load downloads
    List<Download> _d = await downloadManager.getDownloads();
    setState(() {
      downloads = _d;
    });
  }

  @override
  void initState() {
    _load();

    //Subscribe to state update
    _stateSubscription = downloadManager.serviceEvents.stream.listen((e) {
      //State change = update
      if (e['action'] == 'onStateChange') {
        setState(() => downloadManager.running = downloadManager.running);
      }
      //Progress change
      if (e['action'] == 'onProgress') {
        setState(() {
          for (Map su in e['data']) {
            downloads.firstWhere((d) => d.id == su['id'], orElse: () => Download()).updateFromJson(su);
          }
        });
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    if (_stateSubscription != null)
      _stateSubscription.cancel();
    _stateSubscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Downloads'.i18n),
          actions: [
            IconButton(
              icon:
                  Icon(downloadManager.running ? Icons.stop : Icons.play_arrow),
              onPressed: () {
                setState(() {
                  if (downloadManager.running)
                    downloadManager.stop();
                  else
                    downloadManager.start();
                });
              },
            )
          ],
        ),
        body: ListView(
          children: [
            //Now downloading
            Container(height: 2.0),
            Column(children: List.generate(downloading.length, (int i) => DownloadTile(
              downloading[i],
              updateCallback: () => _load(),
            ))),
            Container(height: 8.0),

            //Queued
            if (queued.length > 0)
              Text(
                'Queued'.i18n,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold
                ),
              ),
            Column(children: List.generate(queued.length, (int i) => DownloadTile(
              queued[i],
              updateCallback: () => _load(),
            ))),
            if (queued.length > 0)
              ListTile(
                title: Text('Clear queue'.i18n),
                leading: Icon(Icons.delete),
                onTap: () async {
                  await downloadManager.removeDownloads(DownloadState.NONE);
                  await _load();
                },
              ),

            //Failed
            if (failed.length > 0)
              Text(
                'Failed'.i18n,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold
                ),
              ),
            Column(children: List.generate(failed.length, (int i) => DownloadTile(
              failed[i],
              updateCallback: () => _load(),
            ))),
            //Restart failed
            if (failed.length > 0)
              ListTile(
                title: Text('Restart failed downloads'.i18n),
                leading: Icon(Icons.restore),
                onTap: () async {
                  await downloadManager.retryDownloads();
                  await _load();
                },
              ),
            if (failed.length > 0)
              ListTile(
                title: Text('Clear failed'.i18n),
                leading: Icon(Icons.delete),
                onTap: () async {
                  await downloadManager.removeDownloads(DownloadState.ERROR);
                  await downloadManager.removeDownloads(DownloadState.DEEZER_ERROR);
                  await _load();
                },
              ),

            //Finished
            if (finished.length > 0)
              Text(
                'Done'.i18n,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold
                ),
              ),
            Column(children: List.generate(finished.length, (int i) => DownloadTile(
              finished[i],
              updateCallback: () => _load(),
            ))),
            if (finished.length > 0)
              ListTile(
                title: Text('Clear downloads history'.i18n),
                leading: Icon(Icons.delete),
                onTap: () async {
                  await downloadManager.removeDownloads(DownloadState.DONE);
                  await _load();
                },
              ),

          ],
        )
    );
  }
}

class DownloadTile extends StatelessWidget {

  final Download download;
  final Function updateCallback;
  DownloadTile(this.download, {this.updateCallback});

  String subtitle() {
    String out = '';
    //Download type
    if (download.private) out += 'Offline'.i18n;
    else out += 'External'.i18n;
    out += ' | ';
    //Quality
    if (download.quality == 9) out += 'FLAC';
    if (download.quality == 3) out += 'MP3 320kbps';
    if (download.quality == 1) out += 'MP3 128kbps';

    return out;
  }

  Future onClick(BuildContext context) async {
    if (download.state != DownloadState.DOWNLOADING && download.state != DownloadState.POST) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Delete'.i18n),
            content: Text('Are you sure you want to delete this download?'.i18n),
            actions: [
              FlatButton(
                child: Text('Cancel'.i18n),
                onPressed: () => Navigator.of(context).pop(),
              ),
              FlatButton(
                child: Text('Delete'.i18n),
                onPressed: () async {
                  await downloadManager.removeDownload(download.id);
                  if (updateCallback != null) updateCallback();
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        }
      );
    }
  }

  //Trailing icon with state
  Widget trailing() {
    switch (download.state) {
      case DownloadState.NONE:
        return Icon(
          Icons.query_builder,
        );
      case DownloadState.DOWNLOADING:
        return Icon(
          Icons.download_rounded
        );
      case DownloadState.POST:
        return Icon(
          Icons.miscellaneous_services
        );
      case DownloadState.DONE:
        return Icon(
          Icons.done,
          color: Colors.green,
        );
      case DownloadState.DEEZER_ERROR:
        return Icon(
          Icons.error,
          color: Colors.blue
        );
      case DownloadState.ERROR:
        return Icon(
          Icons.error,
          color: Colors.red
        );
    }
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text(download.title),
          leading: CachedImage(url: download.image),
          subtitle: Text(subtitle()),
          trailing: trailing(),
          onTap: () => onClick(context),
        ),
        if (download.state == DownloadState.DOWNLOADING)
          LinearProgressIndicator(value: download.progress),
        if (download.state == DownloadState.POST)
          LinearProgressIndicator(),
      ],
    );
  }
}