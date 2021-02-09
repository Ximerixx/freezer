package f.f.freezer;

import android.content.pm.PackageManager;
import android.util.Log;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.RandomAccessFile;
import java.net.URL;
import java.util.HashMap;

import javax.net.ssl.HttpsURLConnection;
import fi.iki.elonen.NanoHTTPD;

public class StreamServer {

    public HashMap<String, StreamInfo> streams = new HashMap<>();

    private WebServer server;
    private String host = "127.0.0.1";
    private int port = 36958;
    private String offlinePath;

    //Shared log & API
    private DownloadLog logger;
    private Deezer deezer;

    StreamServer(String arl, String offlinePath) {
        //Initialize shared variables
        logger = new DownloadLog();
        deezer = new Deezer();
        deezer.init(logger, arl);
        this.offlinePath = offlinePath;
    }

    //Create server
    void start() {
        try {
            server = new WebServer(host, port);
            server.start();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    void stop() {
        if (server != null)
            server.stop();
    }

    //Information about streamed audio - for showing in UI
    public class StreamInfo {
        String format;
        long size;
        //"Stream" or "Offline"
        String source;

        StreamInfo(String format, long size, String source) {
            this.format = format;
            this.size = size;
            this.source = source;
        }

        //For passing into UI
        public HashMap<String, Object> toJSON() {
            HashMap<String, Object> out = new HashMap<>();
            out.put("format", format);
            out.put("size", size);
            out.put("source", source);
            return out;
        }

    }

    private class WebServer extends NanoHTTPD {
        public WebServer(String hostname, int port) {
            super(hostname, port);
        }

        @Override
        public Response serve(IHTTPSession session) {
            //Must be only GET
            if (session.getMethod() != Method.GET)
                return newFixedLengthResponse(Response.Status.METHOD_NOT_ALLOWED, MIME_PLAINTEXT, "Only GET request supported!");

            //Parse range header
            String rangeHeader = session.getHeaders().get("range");
            int startBytes = 0;
            boolean isRanged = false;
            int end = -1;
            if (rangeHeader != null && rangeHeader.startsWith("bytes")) {
                isRanged = true;
                String[] ranges = rangeHeader.split("=")[1].split("-");
                startBytes = Integer.parseInt(ranges[0]);
                if (ranges.length > 1 && !ranges[1].equals(" ")) {
                    end = Integer.parseInt(ranges[1]);
                }
            }

            //Check query parameters
            if (session.getParameters().keySet().size() < 4) {
                //Play offline
                if (session.getParameters().get("id") != null) {
                    return offlineStream(session, startBytes, end, isRanged);
                }
                //Missing QP
                return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_PLAINTEXT, "Invalid / Missing QP");
            }

            //Stream
            return deezerStream(session, startBytes, end, isRanged);

        }

        private Response offlineStream(IHTTPSession session, int startBytes, int end, boolean isRanged) {
            //Get path
            String trackId = session.getParameters().get("id").get(0);
            File file = new File(offlinePath, trackId);
            long size = file.length();
            //Read header
            boolean isFlac = false;
            try {
                InputStream inputStream = new FileInputStream(file);
                byte[] buffer = new byte[4];
                inputStream.read(buffer, 0, 4);
                inputStream.close();
                if (new String(buffer).equals("fLaC"))
                    isFlac = true;
            } catch (Exception e) {
                return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_PLAINTEXT, "Invalid file!");
            }
            //Open file
            RandomAccessFile randomAccessFile;
            try {
                randomAccessFile = new RandomAccessFile(file, "r");
                randomAccessFile.seek(startBytes);
            } catch (Exception e) {
                return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_PLAINTEXT, "Failed getting data!");
            }

            //Generate response
            Response response = newFixedLengthResponse(
                    isRanged ? Response.Status.PARTIAL_CONTENT : Response.Status.OK,
                    isFlac ? "audio/flac" : "audio/mpeg",
                    new InputStream() {
                        @Override
                        public int read() throws IOException {
                            return 0;
                        }
                        //Pass thru
                        @Override
                        public int read(byte[] b, int off, int len) throws IOException {
                            return randomAccessFile.read(b, off, len);
                        }
                    },
                    ((end == -1) ? size : end) - startBytes
            );
            //Ranged header
            if (isRanged) {
                String range = "bytes " + Integer.toString(startBytes) + "-" + Long.toString((end == -1) ? size - 1 : end);
                range += "/" + Long.toString(size);
                response.addHeader("Content-Range", range);
            }
            response.addHeader("Accept-Ranges", "bytes");

            //Save stream info
            streams.put(trackId, new StreamInfo((isFlac ? "FLAC" : "MP3"), size, "Offline"));

            return response;
        }

        private Response deezerStream(IHTTPSession session, int startBytes, int end, boolean isRanged) {
            //Get QP into Quality Info
            Deezer.QualityInfo qualityInfo = new Deezer.QualityInfo(
                    Integer.parseInt(session.getParameters().get("q").get(0)),
                    session.getParameters().get("id").get(0),
                    session.getParameters().get("md5origin").get(0),
                    session.getParameters().get("mv").get(0),
                    logger
            );
            //Fallback
            try {
                boolean res = qualityInfo.fallback(deezer);
                if (!res)
                    throw new Exception("No more to fallback!");
            } catch (Exception e) {
                return newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_PLAINTEXT, "Fallback failed!");
            }

            //Passthru
            String sURL = Deezer.getTrackUrl(qualityInfo.trackId, qualityInfo.md5origin, qualityInfo.mediaVersion, qualityInfo.quality);

            try {
                URL url = new URL(sURL);
                HttpsURLConnection connection = (HttpsURLConnection) url.openConnection();
                //Set headers
                connection.setConnectTimeout(10000);
                connection.setRequestMethod("GET");
                connection.setRequestProperty("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.130 Safari/537.36");
                connection.setRequestProperty("Accept-Language", "*");
                connection.setRequestProperty("Accept", "*/*");
                connection.setRequestProperty("Range", "bytes=" + Integer.toString(startBytes) + "-");
                connection.connect();
                //Return response
                Response response = newFixedLengthResponse(
                    isRanged ? Response.Status.PARTIAL_CONTENT : Response.Status.OK,
                    (qualityInfo.quality == 9) ? "audio/flac" : "audio/mpeg",
                    connection.getInputStream(),
                    connection.getContentLength()
                );
                response.addHeader("Accept-Ranges", "bytes");
                //Ranged header
                if (isRanged) {
                    String range = "bytes " + Integer.toString(startBytes) + "-" + Integer.toString((end == -1) ? (connection.getContentLength() + startBytes) - 1 : end);
                    range += "/" + Integer.toString(connection.getContentLength() + startBytes);
                    response.addHeader("Content-Range", range);
                }
                //Save stream info, use original track id
                streams.put(session.getParameters().get("id").get(0), new StreamInfo(
                    ((qualityInfo.quality == 9) ? "FLAC" : "MP3"),
                    startBytes + connection.getContentLength(),
                    "Stream"
                ));
                return response;
            } catch (Exception e) {
                e.printStackTrace();
//                return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_PLAINTEXT, e.toString());
            }

            //Return 404, the player should handle it better i guess
            return newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_PLAINTEXT, "Failed getting data!");
        }
    }
}