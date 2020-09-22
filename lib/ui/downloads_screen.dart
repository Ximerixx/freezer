import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:freezer/translations.i18n.dart';

import 'cached_image.dart';
import '../api/download.dart';


class DownloadTile extends StatelessWidget {

  final Download download;
  Function onDelete;
  DownloadTile(this.download, {this.onDelete});

  String get subtitle {
    switch (download.state) {
      case DownloadState.NONE: return '';
      case DownloadState.DOWNLOADING:
        return '${filesize(download.received)} / ${filesize(download.total)}';
      case DownloadState.POST:
        return 'Post processing...'.i18n;
      case DownloadState.DONE:
        return 'Done'.i18n; //Shouldn't be visible
      case DownloadState.DEEZER_ERROR:
        return 'Track is not available on Deezer!'.i18n;
      case DownloadState.ERROR:
        return 'Failed to download track! Please restart.'.i18n;
    }
    return '';
  }

  Widget get progressBar {
    switch (download.state) {
      case DownloadState.DOWNLOADING:
        return LinearProgressIndicator(value: download.received / download.total);
      case DownloadState.POST:
        return LinearProgressIndicator();
      default:
        return Container(height: 0, width: 0,);
    }
  }

  Widget get trailing {
    if (download.private) {
      return Icon(Icons.offline_pin);
    }
    return Icon(Icons.sd_card);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          title: Text(download.track.title),
          subtitle: Text(subtitle),
          leading: CachedImage(
            url: download.track.albumArt.thumb,
            width: 48.0,
          ),
          trailing: trailing,
          onTap: () {
            //Delete if none
            if (download.state == DownloadState.NONE) {
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
                        onPressed: () {
                          downloadManager.removeDownload(download);
                          if (this.onDelete != null) this.onDelete();
                          Navigator.of(context).pop();
                        },
                      )
                    ],
                  );
                }
              );
            }
          },
        ),
        progressBar
      ],
    );
  }
}

class DownloadsScreen extends StatefulWidget {
  @override
  _DownloadsScreenState createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Downloads'.i18n),
          actions: [
            IconButton(
              icon: Icon(downloadManager.stopped ? Icons.play_arrow : Icons.stop),
              onPressed: () {
                setState(() {
                  if (downloadManager.stopped) downloadManager.start();
                  else downloadManager.stop();
                });
              },
            )
          ],
        ),
        body: ListView(
          children: <Widget>[
            StreamBuilder(
              stream: Stream.periodic(Duration(milliseconds: 500)).asBroadcastStream(), //Periodic to get current download progress
              builder: (BuildContext context, AsyncSnapshot snapshot) {

                if (downloadManager.queue.length == 0)
                  return Container(width: 0, height: 0,);

                return Column(
                    children: [
                      ...List.generate(downloadManager.queue.length, (i) {
                        return DownloadTile(downloadManager.queue[i], onDelete: () => setState(() => {}));
                      }),
                      if (downloadManager.queue.length > 1 || (downloadManager.stopped && downloadManager.queue.length > 0))
                        ListTile(
                          title: Text('Clear queue'.i18n),
                          subtitle: Text("This won't delete currently downloading item".i18n),
                          leading: Icon(Icons.delete),
                          onTap: () async {
                            showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: Text('Delete'.i18n),
                                    content: Text('Are you sure you want to delete all queued downloads?'.i18n),
                                    actions: [
                                      FlatButton(
                                        child: Text('Cancel'.i18n),
                                        onPressed: () => Navigator.of(context).pop(),
                                      ),
                                      FlatButton(
                                        child: Text('Delete'.i18n),
                                        onPressed: () async {
                                          await downloadManager.clearQueue();
                                          Navigator.of(context).pop();
                                        },
                                      )
                                    ],
                                  );
                                }
                            );
                          },
                        )
                    ]
                );
              },
            ),
            FutureBuilder(
              future: downloadManager.getFinishedDownloads(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data.length == 0) return Container(height: 0, width: 0,);

                return Column(
                  children: <Widget>[
                    Divider(),
                    Text(
                      'History',
                      style: TextStyle(
                          fontSize: 24.0,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                    ...List.generate(snapshot.data.length, (i) {
                      Download d = snapshot.data[i];
                      return DownloadTile(d);
                    }),
                    ListTile(
                      title: Text('Clear downloads history'.i18n),
                      leading: Icon(Icons.delete),
                      subtitle: Text('WARNING: This will only clear non-offline (external downloads)'.i18n),
                      onTap: () async {
                        await downloadManager.cleanDownloadHistory();
                        setState(() {});
                      },
                    ),
                  ],
                );
              },
            )
          ],
        )
    );
  }
}


