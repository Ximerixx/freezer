package f.f.freezer;

import android.content.Context;
import android.util.Log;

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
import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.io.RandomAccessFile;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.Map;
import java.util.Scanner;

import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;
import javax.net.ssl.HttpsURLConnection;

public class Deezer {

    DownloadLog logger;

    //Initialize for logging
    void init(DownloadLog logger) {
        this.logger = logger;
    }

    //Get guest SID cookie from deezer.com
    public static String getSidCookie() throws Exception {
        URL url = new URL("https://deezer.com/");
        HttpsURLConnection connection = (HttpsURLConnection) url.openConnection();
        connection.setConnectTimeout(20000);
        connection.setRequestMethod("HEAD");
        String sid = "";
        for (String cookie : connection.getHeaderFields().get("Set-Cookie")) {
            if (cookie.startsWith("sid=")) {
                sid = cookie.split(";")[0].split("=")[1];
            }
        }
        return sid;
    }

    //Same as gw_light API, but doesn't need authentication
    public static JSONObject callMobileAPI(String method, String params) throws Exception{
        String sid = Deezer.getSidCookie();

        URL url = new URL("https://api.deezer.com/1.0/gateway.php?api_key=4VCYIJUCDLOUELGD1V8WBVYBNVDYOXEWSLLZDONGBBDFVXTZJRXPR29JRLQFO6ZE&sid=" + sid + "&input=3&output=3&method=" + method);
        HttpsURLConnection connection = (HttpsURLConnection) url.openConnection();
        connection.setConnectTimeout(20000);
        connection.setDoOutput(true);
        connection.setRequestMethod("POST");
        connection.setRequestProperty("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.130 Safari/537.36");
        connection.setRequestProperty("Accept-Language", "*");
        connection.setRequestProperty("Content-Type", "application/json");
        connection.setRequestProperty("Accept", "*/*");
        connection.setRequestProperty("Content-Length", Integer.toString(params.getBytes(StandardCharsets.UTF_8).length));

        //Write body
        DataOutputStream wr = new DataOutputStream(connection.getOutputStream());
        wr.writeBytes(params);
        wr.close();
        //Get response
        String data = "";
        Scanner scanner = new Scanner(connection.getInputStream());
        while (scanner.hasNext()) {
            data += scanner.nextLine();
        }

        //Parse JSON
        JSONObject out = new JSONObject(data);
        return out;
    }

    //api.deezer.com/$method/$param
    public static JSONObject callPublicAPI(String method, String param) throws Exception {
        URL url = new URL("https://api.deezer.com/" + method + "/" + param);
        HttpsURLConnection connection = (HttpsURLConnection)url.openConnection();
        connection.setRequestMethod("GET");
        connection.setConnectTimeout(20000);
        connection.connect();

        //Get string data
        String data = "";
        Scanner scanner = new Scanner(url.openStream());
        while (scanner.hasNext()) {
            data += scanner.nextLine();
        }

        //Parse JSON
        JSONObject out = new JSONObject(data);
        return out;
    }

    public int qualityFallback(String trackId, String md5origin, String mediaVersion, int originalQuality) throws Exception {
        //Create HEAD requests to check if exists
        URL url = new URL(getTrackUrl(trackId, md5origin, mediaVersion, originalQuality));
        HttpsURLConnection connection = (HttpsURLConnection) url.openConnection();
        connection.setRequestMethod("HEAD");
        int rc = connection.getResponseCode();
        //Track not available
        if (rc > 400) {
            logger.warn("Quality fallback, response code: " + Integer.toString(rc) + ", current: " + Integer.toString(originalQuality));
            //Returns -1 if no quality available
            if (originalQuality == 1) return -1;
            if (originalQuality == 3) return qualityFallback(trackId, md5origin, mediaVersion, 1);
            if (originalQuality == 9) return qualityFallback(trackId, md5origin, mediaVersion, 3);
        }
        return originalQuality;
    }

    //Generate track download URL
    public static String getTrackUrl(String trackId, String md5origin, String mediaVersion, int quality) {
        try {
            int magic = 164;

            ByteArrayOutputStream step1 = new ByteArrayOutputStream();
            step1.write(md5origin.getBytes());
            step1.write(magic);
            step1.write(Integer.toString(quality).getBytes());
            step1.write(magic);
            step1.write(trackId.getBytes());
            step1.write(magic);
            step1.write(mediaVersion.getBytes());
            //Get MD5
            MessageDigest md5 = MessageDigest.getInstance("MD5");
            md5.update(step1.toByteArray());
            byte[] digest = md5.digest();
            String md5hex = bytesToHex(digest).toLowerCase();

            //Step 2
            ByteArrayOutputStream step2 = new ByteArrayOutputStream();
            step2.write(md5hex.getBytes());
            step2.write(magic);
            step2.write(step1.toByteArray());
            step2.write(magic);

            //Pad step2 with dots, to get correct length
            while(step2.size()%16 > 0) step2.write(46);

            //Prepare AES encryption
            Cipher cipher = Cipher.getInstance("AES/ECB/NoPadding");
            SecretKeySpec key = new SecretKeySpec("jo6aey6haid2Teih".getBytes(), "AES");
            cipher.init(Cipher.ENCRYPT_MODE, key);
            //Encrypt
            StringBuilder step3 = new StringBuilder();
            for (int i=0; i<step2.size()/16; i++) {
                byte[] b = Arrays.copyOfRange(step2.toByteArray(), i*16, (i+1)*16);
                step3.append(bytesToHex(cipher.doFinal(b)).toLowerCase());
            }
            //Join to URL
            return "https://e-cdns-proxy-" + md5origin.charAt(0) + ".dzcdn.net/mobile/1/" + step3.toString();

        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
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
    private static byte[] getKey(String id) {
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
        } catch (Exception e) {}
        return key.getBytes();
    }

    //Decrypt 2048b chunk
    private static byte[] decryptChunk(byte[] key, byte[] data) throws Exception{
        byte[] IV = {00, 01, 02, 03, 04, 05, 06, 07};
        SecretKeySpec Skey = new SecretKeySpec(key, "Blowfish");
        Cipher cipher = Cipher.getInstance("Blowfish/CBC/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, Skey, new javax.crypto.spec.IvParameterSpec(IV));
        return cipher.doFinal(data);
    }

    public static void decryptTrack(String path, String tid) throws Exception {
        //Load file
        File inputFile = new File(path);
        BufferedInputStream buffin = new BufferedInputStream(new FileInputStream(inputFile));
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        byte[] key = getKey(tid);
        for (int i=0; i<(inputFile.length()/2048)+1; i++) {
            byte[] tmp = new byte[2048];
            int read = buffin.read(tmp, 0, tmp.length);
            if ((i%3) == 0 && read == 2048) {
                tmp = decryptChunk(key, tmp);
            }
            buf.write(tmp, 0, read);
        }
        //Save
        FileOutputStream outputStream = new FileOutputStream(new File(path));
        outputStream.write(buf.toByteArray());
        outputStream.close();
    }

    public static String sanitize(String input) {
        return input.replaceAll("[\\\\/?*:%<>|\"]", "").replace("$", "\\$");
    }

    public static String generateFilename(String original, JSONObject publicTrack, JSONObject publicAlbum, int newQuality) throws Exception {
        original = original.replaceAll("%title%", sanitize(publicTrack.getString("title")));
        original = original.replaceAll("%album%", sanitize(publicTrack.getJSONObject("album").getString("title")));
        original = original.replaceAll("%artist%", sanitize(publicTrack.getJSONObject("artist").getString("name")));
        //Artists
        String artists = "";
        String feats = "";
        for (int i=0; i<publicTrack.getJSONArray("contributors").length(); i++) {
            artists += ", " + publicTrack.getJSONArray("contributors").getJSONObject(i).getString("name");
            if (i > 0)
                feats += ", " + publicTrack.getJSONArray("contributors").getJSONObject(i).getString("name");
        }
        original = original.replaceAll("%artists%", sanitize(artists).substring(2));
        if (feats.length() >= 2)
            original = original.replaceAll("%feats%", sanitize(feats).substring(2));
        //Track number
        int trackNumber = publicTrack.getInt("track_position");
        original = original.replaceAll("%trackNumber%", Integer.toString(trackNumber));
        original = original.replaceAll("%0trackNumber%", String.format("%02d", trackNumber));
        //Year
        original = original.replaceAll("%year%", publicTrack.getString("release_date").substring(0, 4));
        original = original.replaceAll("%date%", publicTrack.getString("release_date"));

        if (newQuality == 9) return original + ".flac";
        return original + ".mp3";
    }

    //Tag track with data from API
    public static void tagTrack(String path, JSONObject publicTrack, JSONObject publicAlbum, String cover) throws Exception {
        TagOptionSingleton.getInstance().setAndroid(true);
        //Load file
        AudioFile f = AudioFileIO.read(new File(path));
        boolean isFlac = true;
        if (f.getAudioHeader().getFormat().contains("MPEG")) {
            f.setTag(new ID3v23Tag());
            isFlac = false;
        }
        Tag tag = f.getTag();

        tag.setField(FieldKey.TITLE, publicTrack.getString("title"));
        tag.setField(FieldKey.ALBUM, publicTrack.getJSONObject("album").getString("title"));
        //Artist
        for (int i=0; i<publicTrack.getJSONArray("contributors").length(); i++) {
            tag.addField(FieldKey.ARTIST, publicTrack.getJSONArray("contributors").getJSONObject(i).getString("name"));
        }
        tag.setField(FieldKey.TRACK, Integer.toString(publicTrack.getInt("track_position")));
        tag.setField(FieldKey.DISC_NO, Integer.toString(publicTrack.getInt("disk_number")));
        tag.setField(FieldKey.ALBUM_ARTIST, publicAlbum.getJSONObject("artist").getString("name"));
        tag.setField(FieldKey.YEAR, publicTrack.getString("release_date").substring(0, 4));
        tag.setField(FieldKey.BPM, Integer.toString((int)publicTrack.getDouble("bpm")));
        tag.setField(FieldKey.RECORD_LABEL, publicAlbum.getString("label"));
        //Genres
        for (int i=0; i<publicAlbum.getJSONObject("genres").getJSONArray("data").length(); i++) {
            String genre = publicAlbum.getJSONObject("genres").getJSONArray("data").getJSONObject(0).getString("name");
            tag.addField(FieldKey.GENRE, genre);
        }

        File coverFile = new File(cover);
        boolean addCover = (coverFile.exists() && coverFile.length() > 0);

        if (isFlac) {
            //FLAC Specific tags
            ((FlacTag)tag).setField("DATE", publicTrack.getString("release_date"));
            ((FlacTag)tag).setField("TRACKTOTAL", Integer.toString(publicAlbum.getInt("nb_tracks")));
            //Cover
            if (addCover) {
                RandomAccessFile cf = new RandomAccessFile(coverFile, "r");
                byte[] coverData = new byte[(int) cf.length()];
                cf.read(coverData);
                tag.setField(((FlacTag)tag).createArtworkField(
                    coverData,
                    PictureTypes.DEFAULT_ID,
                    ImageFormats.MIME_TYPE_JPEG,
                    "cover",
                    1400,
                    1400,
                    24,
                    0
                ));
            }
        } else {
            if (addCover) {
                Artwork art = Artwork.createArtworkFromFile(coverFile);
                tag.addField(art);
            }
        }

        //Save
        AudioFileIO.write(f);
    }

    //Create JSON file, privateJsonData = `song.getLyrics`
    public static String generateLRC(JSONObject privateJsonData, JSONObject publicTrack) throws Exception {
        String output = "";

        //Create metadata
        String title = publicTrack.getString("title");
        String album = publicTrack.getJSONObject("album").getString("title");
        String artists = "";
        for (int i=0; i<publicTrack.getJSONArray("contributors").length(); i++) {
            artists += ", " + publicTrack.getJSONArray("contributors").getJSONObject(i).getString("name");
        }
        //Write metadata
        output += "[ar:" + artists.substring(2) + "]\r\n[al:" + album + "]\r\n[ti:" + title + "]\r\n";

        //Get lyrics
        int counter = 0;
        JSONArray syncLyrics = privateJsonData.getJSONObject("results").getJSONArray("LYRICS_SYNC_JSON");
        for (int i=0; i<syncLyrics.length(); i++) {
            JSONObject lyric = syncLyrics.getJSONObject(i);
            if (lyric.has("lrc_timestamp") && lyric.has("line")) {
                output += lyric.getString("lrc_timestamp") + lyric.getString("line") + "\r\n";
                counter += 1;
            }
        }

        if (counter == 0) throw new Exception("Empty Lyrics!");
        return output;
    }

}