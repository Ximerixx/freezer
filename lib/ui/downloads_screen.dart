import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';

import 'cached_image.dart';
import '../api/download.dart';


class DownloadTile extends StatelessWidget {

  final Download download;
  DownloadTile(this.download);

  String get subtitle {
    switch (download.state) {
      case DownloadState.NONE: return '';
      case DownloadState.DOWNLOADING:
        return '${filesize(download.received)} / ${filesize(download.total)}';
      case DownloadState.POST:
        return 'Post processing...';
      case DownloadState.DONE:
        return 'Done'; //Shouldn't be visible
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
          ),
          trailing: trailing,
        ),
        progressBar
      ],
    );
  }
}

class DownloadsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Downloads'),
      ),
      body: ListView(
        children: <Widget>[
          StreamBuilder(
            stream: Stream.periodic(Duration(milliseconds: 500)), //Periodic to get current download progress
            builder: (BuildContext context, AsyncSnapshot snapshot) {

              if (downloadManager.queue.length == 0)
                return Container(width: 0, height: 0,);

              return Column(
                children: List.generate(downloadManager.queue.length, (i) {
                  return DownloadTile(downloadManager.queue[i]);
                })
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
                  })
                ],
              );
            },
          )
        ],
      )
    );
  }
}