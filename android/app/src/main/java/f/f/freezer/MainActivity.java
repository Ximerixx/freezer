package f.f.freezer;

import android.content.ComponentName;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.os.Messenger;
import android.os.RemoteException;
import android.util.Log;

import androidx.annotation.NonNull;

import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

import static f.f.freezer.Deezer.bytesToHex;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "f.f.freezer/native";
    private static final String EVENT_CHANNEL = "f.f.freezer/downloads";
    EventChannel.EventSink eventSink;

    boolean serviceBound = false;
    Messenger serviceMessenger;
    Messenger activityMessenger;
    SQLiteDatabase db;

    private static final int SD_PERMISSION_REQUEST_CODE = 42;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);

        //Flutter method channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL).setMethodCallHandler((((call, result) -> {

            //Add downloads to DB, then refresh service
            if (call.method.equals("addDownloads")) {
                //TX
                db.beginTransaction();

                ArrayList<HashMap> downloads = call.arguments();
                for (int i=0; i<downloads.size(); i++) {
                    //Check if exists
                    Cursor cursor = db.rawQuery("SELECT id, state FROM Downloads WHERE trackId == ? AND path == ?",
                            new String[]{(String)downloads.get(i).get("trackId"), (String)downloads.get(i).get("path")});
                    if (cursor.getCount() > 0) {
                        //If done or error, set state to NONE - they should be skipped because file exists
                        cursor.moveToNext();
                        if (cursor.getInt(1) >= 3) {
                            ContentValues values = new ContentValues();
                            values.put("state", 0);
                            db.update("Downloads", values, "id == ?", new String[]{Integer.toString(cursor.getInt(0))});
                            Log.d("INFO", "Already exists in DB, updating to none state!");
                        } else {
                            Log.d("INFO", "Already exits in DB!");
                        }
                        cursor.close();
                        continue;
                    }
                    cursor.close();

                    //Insert
                    ContentValues row = Download.flutterToSQL(downloads.get(i));
                    db.insert("Downloads", null, row);
                }
                db.setTransactionSuccessful();
                db.endTransaction();
                //Update service
                sendMessage(DownloadService.SERVICE_LOAD_DOWNLOADS, null);

                result.success(null);
                return;
            }

            //Get all downloads from DB
            if (call.method.equals("getDownloads")) {
                Cursor cursor = db.query("Downloads", null, null, null, null, null, null);
                ArrayList downloads = new ArrayList();
                //Parse downloads
                while (cursor.moveToNext()) {
                    Download download = Download.fromSQL(cursor);
                    downloads.add(download.toHashMap());
                }
                cursor.close();
                result.success(downloads);
                return;
            }
            //Update settings from UI
            if (call.method.equals("updateSettings")) {
                Bundle bundle = new Bundle();
                bundle.putInt("downloadThreads", (int)call.argument("downloadThreads"));
                bundle.putBoolean("overwriteDownload", (boolean)call.argument("overwriteDownload"));
                bundle.putBoolean("downloadLyrics", (boolean)call.argument("downloadLyrics"));
                sendMessage(DownloadService.SERVICE_SETTINGS_UPDATE, bundle);

                result.success(null);
                return;
            }
            //Load downloads from DB in service
            if (call.method.equals("loadDownloads")) {
                sendMessage(DownloadService.SERVICE_LOAD_DOWNLOADS, null);
                result.success(null);
                return;
            }
            //Start/Resume downloading
            if (call.method.equals("start")) {
                sendMessage(DownloadService.SERVICE_START_DOWNLOAD, null);
                result.success(null);
                return;
            }
            //Stop downloading
            if (call.method.equals("stop")) {
                sendMessage(DownloadService.SERVICE_STOP_DOWNLOADS, null);
                result.success(null);
                return;
            }
            //Remove download
            if (call.method.equals("removeDownload")) {
                Bundle bundle = new Bundle();
                bundle.putInt("id", (int)call.argument("id"));
                sendMessage(DownloadService.SERVICE_REMOVE_DOWNLOAD, bundle);
                result.success(null);
                return;
            }
            //Retry download
            if (call.method.equals("retryDownloads")) {
                sendMessage(DownloadService.SERVICE_RETRY_DOWNLOADS, null);
                result.success(null);
                return;
            }
            //Remove downloads by state
            if (call.method.equals("removeDownloads")) {
                Bundle bundle = new Bundle();
                bundle.putInt("state", (int)call.argument("state"));
                sendMessage(DownloadService.SERVICE_REMOVE_DOWNLOADS, bundle);
                result.success(null);
                return;
            }


            result.error("0", "Not implemented!", "Not implemented!");
        })));


        //Event channel (for download updates)
        EventChannel eventChannel = new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), EVENT_CHANNEL);
        eventChannel.setStreamHandler((new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                eventSink = events;
            }

            @Override
            public void onCancel(Object arguments) {
                eventSink = null;
            }
        }));
    }


    @Override
    protected void onStart() {
        super.onStart();
        //Bind downloader service
        activityMessenger = new Messenger(new IncomingHandler(this));
        Intent intent = new Intent(this, DownloadService.class);
        intent.putExtra("activityMessenger", activityMessenger);
        bindService(intent, connection, Context.BIND_AUTO_CREATE);
        //Get DB
        DownloadsDatabase dbHelper = new DownloadsDatabase(getApplicationContext());
        db = dbHelper.getWritableDatabase();
    }

    @Override
    protected void onStop() {
        super.onStop();
        //Unbind service on exit
        if (serviceBound) {
            unbindService(connection);
            serviceBound = false;
        }
        db.close();
    }

    //Connection to download service
    private ServiceConnection connection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName componentName, IBinder iBinder) {
            serviceMessenger = new Messenger(iBinder);
            serviceBound = true;
        }

        @Override
        public void onServiceDisconnected(ComponentName componentName) {
            serviceMessenger = null;
            serviceBound = false;
        }
    };

    //Handler for incoming messages from service
    class IncomingHandler extends Handler {
        IncomingHandler(Context context) {
            Context applicationContext = context.getApplicationContext();
        }

        @Override
        public void handleMessage(Message msg) {
            switch (msg.what) {

                //Forward to flutter.
                case DownloadService.SERVICE_ON_PROGRESS:
                    if (eventSink == null) break;
                    if (msg.getData().getParcelableArrayList("downloads").size() > 0) {
                        //Generate HashMap ArrayList for sending to flutter
                        ArrayList<HashMap> data = new ArrayList<>();
                        for (int i=0; i<msg.getData().getParcelableArrayList("downloads").size(); i++) {
                            Bundle bundle = (Bundle) msg.getData().getParcelableArrayList("downloads").get(i);
                            HashMap out = new HashMap();
                            out.put("id", bundle.getInt("id"));
                            out.put("state", bundle.getInt("state"));
                            out.put("received", bundle.getLong("received"));
                            out.put("filesize", bundle.getLong("filesize"));
                            out.put("quality", bundle.getInt("quality"));
                            data.add(out);
                        }
                        //Wrapper
                        HashMap out = new HashMap();
                        out.put("action", "onProgress");
                        out.put("data", data);
                        eventSink.success(out);
                    }

                    break;
                //State change, forward to flutter
                case DownloadService.SERVICE_ON_STATE_CHANGE:
                    if (eventSink == null) break;
                    Bundle b = msg.getData();
                    HashMap out = new HashMap();
                    out.put("running", b.getBoolean("running"));
                    out.put("queueSize", b.getInt("queueSize"));

                    //Wrapper info
                    out.put("action", "onStateChange");

                    eventSink.success(out);
                    break;

                default:
                    super.handleMessage(msg);
            }
        }
    }

    //Send message to service
    void sendMessage(int type, Bundle data) {
        if (serviceBound && serviceMessenger != null) {
            Message msg = Message.obtain(null, type);
            msg.setData(data);
            try {
                serviceMessenger.send(msg);
            } catch (RemoteException e) {
                e.printStackTrace();
            }
        }
    }

    /*
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler(((call, result) -> {
                //Decrypt track
                if (call.method.equals("decryptTrack")) {
                    String tid = call.argument("id").toString();
                    String path = call.argument("path");
                    decryptTrack(path, tid);
                    result.success(0);
                }
                //Android media scanner
                if (call.method.equals("rescanLibrary")) {
                    String path = call.argument("path");
                    Uri uri = Uri.fromFile(new File(path));
                    sendBroadcast(new Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, uri));
                    result.success(0);
                }
                //Add tags to track
                if (call.method.equals("tagTrack")) {
                    try {
                        //Tag
                        TagOptionSingleton.getInstance().setAndroid(true);
                        AudioFile f = AudioFileIO.read(new File(call.argument("path").toString()));
                        boolean isFlac = true;
                        if (f.getAudioHeader().getFormat().contains("MPEG")) {
                            f.setTag(new ID3v23Tag());
                            isFlac = false;
                        }

                        Tag tag = f.getTag();
                        tag.setField(FieldKey.TITLE, call.argument("title").toString());
                        tag.setField(FieldKey.ALBUM, call.argument("album").toString());
                        tag.setField(FieldKey.ARTIST, call.argument("artists").toString());
                        tag.setField(FieldKey.TRACK, call.argument("trackNumber").toString());
                        if (call.argument("albumArtist") != null)
                            tag.setField(FieldKey.ALBUM_ARTIST, call.argument("albumArtist").toString());
                        if (call.argument("diskNumber") != null)
                            tag.setField(FieldKey.DISC_NO, call.argument("diskNumber").toString());
                        if (call.argument("year") != null)
                            tag.setField(FieldKey.YEAR, call.argument("year").toString());
                        if (call.argument("bpm") != null)
                            tag.setField(FieldKey.BPM, call.argument("bpm").toString());
                        if (call.argument("label") != null)
                            tag.setField(FieldKey.RECORD_LABEL, call.argument("label").toString());
                        //Genres
                        ArrayList<String> genres = call.argument("genres");
                        for(int i=0; i<genres.size(); i++) {
                            tag.addField(FieldKey.GENRE, genres.get(i));
                        }

                        //Album art
                        String cover = call.argument("cover").toString();
                        if (isFlac) {
                            //FLAC Specific tags
                            if (call.argument("date") != null)
                                ((FlacTag) tag).setField("DATE", call.argument("date").toString());
                            if (call.argument("albumTracks") != null)
                                ((FlacTag) tag).setField("TRACKTOTAL", call.argument("albumTracks").toString());
                            ((FlacTag) tag).setField("ITUNESADVISORY", call.argument("explicit").toString());


                            //FLAC requires different cover adding
                            RandomAccessFile imageFile = new RandomAccessFile(new File(cover), "r");
                            byte[] imageData = new byte[(int) imageFile.length()];
                            imageFile.read(imageData);
                            tag.setField(((FlacTag) tag).createArtworkField(
                                imageData,
                                PictureTypes.DEFAULT_ID,
                                ImageFormats.MIME_TYPE_JPG,
                                "cover",
                                1400,
                                1400,
                                24,
                                0
                            ));
                        } else {
                            //MP3
                            Artwork art = Artwork.createArtworkFromFile(new File(cover));
                            tag.addField(art);
                        }
                        //Save
                        AudioFileIO.write(f);

                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                    result.success(null);
                }

            }));
    }

    */
}
