package com.ryanheise.just_audio;

import android.net.Uri;
import android.util.Log;
import com.google.android.exoplayer2.upstream.DataSpec;
import com.google.android.exoplayer2.upstream.HttpDataSource;
import com.google.android.exoplayer2.upstream.TransferListener;
import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;

public class DeezerDataSource implements HttpDataSource {
    HttpURLConnection connection;
    InputStream inputStream;
    int counter = 0;
    byte[] key;
    DataSpec dataSpec;

    //Quality fallback stuff
    String trackId;
    int quality = 0;
    String md5origin;
    String mediaVersion;

    public DeezerDataSource(String trackId) {
        this.trackId = trackId;
        this.key = getKey(trackId);
    }

    @Override
    public long open(DataSpec dataSpec) throws HttpDataSource.HttpDataSourceException {
        this.dataSpec = dataSpec;
        try {
            //Check if real url or placeholder for quality fallback
            URL url = new URL(dataSpec.uri.toString());
            String[] qp = url.getQuery().split("&");
            //Real deezcdn url doesnt have query params
            if (qp.length >= 3) {
                //Parse query parameters
                for (int i = 0; i < qp.length; i++) {
                    String p = qp[i].replace("?", "");
                    if (p.startsWith("md5")) {
                        this.md5origin = p.replace("md5=", "");
                    }
                    if (p.startsWith("mv")) {
                        this.mediaVersion = p.replace("mv=", "");
                    }
                    if (p.startsWith("q")) {
                        if (this.quality == 0) {
                            this.quality = Integer.parseInt(p.replace("q=", ""));
                        }
                    }
                }
                //Get real url
                url = new URL(this.getTrackUrl(trackId, md5origin, mediaVersion, quality));
            }


            this.connection = (HttpURLConnection) url.openConnection();
            this.connection.setChunkedStreamingMode(2048);
            if (dataSpec.position > 0) {
                this.counter = (int) (dataSpec.position/2048);
                this.connection.setRequestProperty("Range",
                        "bytes=" + Long.toString(this.counter*2048) + "-");
            }

            InputStream is = this.connection.getInputStream();
            this.inputStream = new BufferedInputStream(new FilterInputStream(is) {
                @Override
                public int read(byte buffer[], int offset, int len) throws IOException {
                    byte[] b = new byte[2048];
                    int t = 0;
                    int read = 0;
                    while (read != -1 && t != 2048) {
                        t += read = in.read(b, t, 2048-t);
                    }

                    if (counter % 3 == 0) {
                        byte[] dec = decryptChunk(key, b);
                        System.arraycopy(dec, 0, buffer, offset, 2048);
                    } else {
                        System.arraycopy(b, 0, buffer, offset, 2048);
                    }
                    counter++;

                    return t;

                }
            },2048);


        } catch (Exception e) {
            //Quality fallback
            if (this.quality == 1) {
                Log.e("E", e.toString());
                throw new HttpDataSourceException("Error loading URL", dataSpec, HttpDataSourceException.TYPE_OPEN);
            }
            if (this.quality == 3) this.quality = 1;
            if (this.quality == 9) this.quality = 3;
            // r e c u r s i o n
            return this.open(dataSpec);
        }
        String size = this.connection.getHeaderField("Content-Length");
        return Long.parseLong(size);
    }

    @Override
    public int read(byte[] buffer, int offset, int length) throws HttpDataSourceException {
        int read = 0;
        try {
            read = this.inputStream.read(buffer, offset, length);
        } catch (Exception e) {
            Log.e("E", e.toString());
            //throw new HttpDataSourceException("Error reading from stream", this.dataSpec, HttpDataSourceException.TYPE_READ);
        }
        return read;
    }
    @Override
    public void close() {
        try {
            if (this.inputStream != null) this.inputStream.close();
            if (this.connection != null) this.connection.disconnect();
        } catch (Exception e) {
            Log.e("E", e.toString());
        }
    }

    @Override
    public void setRequestProperty(String name, String value) {
        Log.d("D", "setRequestProperty");
    }

    @Override
    public void clearRequestProperty(String name) {
        Log.d("D", "clearRequestProperty");
    }

    @Override
    public void clearAllRequestProperties() {
        Log.d("D", "clearAllRequestProperties");
    }

    @Override
    public int getResponseCode() {
        Log.d("D", "getResponseCode");
        return 0;
    }

    @Override
    public Map<String, List<String>> getResponseHeaders() {
        return this.connection.getHeaderFields();
    }

    public final void addTransferListener(TransferListener transferListener) {
        Log.d("D", "addTransferListener");
    }

    @Override
    public Uri getUri() {
        return Uri.parse(this.connection.getURL().toString());
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

    byte[] getKey(String id) {
        String secret = "g4el58wc0zvf9na1";
        try {
            MessageDigest md5 = MessageDigest.getInstance("MD5");
            md5.update(id.getBytes());
            byte[] md5id = md5.digest();
            String idmd5 = bytesToHex(md5id).toLowerCase();
            String key = "";
            for(int i=0; i<16; i++) {
                int s0 = idmd5.charAt(i);
                int s1 = idmd5.charAt(i+16);
                int s2 = secret.charAt(i);
                key += (char)(s0^s1^s2);
            }
            return key.getBytes();
        } catch (Exception e) {
            Log.e("E", e.toString());
            return new byte[0];
        }
    }


    byte[] decryptChunk(byte[] key, byte[] data) {
        try {
            byte[] IV = {00, 01, 02, 03, 04, 05, 06, 07};
            SecretKeySpec Skey = new SecretKeySpec(key, "Blowfish");
            Cipher cipher = Cipher.getInstance("Blowfish/CBC/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, Skey, new javax.crypto.spec.IvParameterSpec(IV));
            return cipher.doFinal(data);
        }catch (Exception e) {
            Log.e("D", e.toString());
            return new byte[0];
        }
    }

    public String getTrackUrl(String trackId, String md5origin, String mediaVersion, int quality) {
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
}