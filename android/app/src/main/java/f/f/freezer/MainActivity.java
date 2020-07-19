package f.f.freezer;

import android.content.Intent;
import android.net.Uri;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.jaudiotagger.audio.AudioFile;
import org.jaudiotagger.audio.AudioFileIO;
import org.jaudiotagger.tag.FieldKey;
import org.jaudiotagger.tag.Tag;
import org.jaudiotagger.tag.TagOptionSingleton;
import org.jaudiotagger.tag.datatype.Artwork;
import org.jaudiotagger.tag.flac.FlacTag;
import org.jaudiotagger.tag.id3.ID3v23Tag;
import org.jaudiotagger.tag.id3.valuepair.ImageFormats;
import org.jaudiotagger.tag.reference.PictureTypes;

import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.RandomAccessFile;
import java.security.MessageDigest;
import java.util.function.Function;

import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "f.f.freezer/native";

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

                        //Album art
                        String cover = call.argument("cover").toString();
                        if (isFlac) {
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

    public static void decryptTrack(String path, String tid) {
        try {
            //Load file
            File inputFile = new File(path + ".ENC");
            BufferedInputStream buffin = new BufferedInputStream(new FileInputStream(inputFile));
            ByteArrayOutputStream buf = new ByteArrayOutputStream();
            byte[] key = getKey(tid);
            for (int i=0; i<inputFile.length()/2048; i++) {
                byte[] tmp = new byte[2048];
                buffin.read(tmp, 0, tmp.length);
                if ((i%3) == 0) {
                    tmp = decryptChunk(key, tmp);
                }
                buf.write(tmp);
            }
            //Save
            FileOutputStream outputStream = new FileOutputStream(new File(path));
            outputStream.write(buf.toByteArray());
            outputStream.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }


    public static String bytesToHex(byte[] bytes) {
        final char[] HEX_ARRAY = "0123456789ABCDEF".toCharArray();
        char[] hexChars = new char[bytes.length * 2];
        for (int j = 0; j < bytes.length; j++) {
            int v = bytes[j] & 0xFF;
            hexChars[j * 2] = HEX_ARRAY[v >>> 4];
            hexChars[j * 2 + 1] = HEX_ARRAY[v & 0x0F];
        }
        return new String(hexChars);
    }

    //Calculate decryption key from track id
    public static byte[] getKey(String id) {
        String secret = "g4el58wc0zvf9na1";
        String key = "";
        try {
            MessageDigest md5 = MessageDigest.getInstance("MD5");
            //md5.update(id.getBytes());
            byte[] md5id = md5.digest(id.getBytes());
            String idmd5 = bytesToHex(md5id).toLowerCase();

            for(int i=0; i<16; i++) {
                int s0 = idmd5.charAt(i);
                int s1 = idmd5.charAt(i+16);
                int s2 = secret.charAt(i);
                key += (char)(s0^s1^s2);
            }
        } catch (Exception e) {
        }
        return key.getBytes();
    }

    //Decrypt 2048b chunk
    public static byte[] decryptChunk(byte[] key, byte[] data) throws Exception{
        byte[] IV = {00, 01, 02, 03, 04, 05, 06, 07};
        SecretKeySpec Skey = new SecretKeySpec(key, "Blowfish");
        Cipher cipher = Cipher.getInstance("Blowfish/CBC/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, Skey, new javax.crypto.spec.IvParameterSpec(IV));
        return cipher.doFinal(data);
    }
}
