import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

/**
 * Memory guard for Teedy's OCR on small Railway plans.
 *
 * OCR of a scanned page (rendered at 300 DPI, upscaled to 3500 px, then tesseract) needs about
 * 0.6 GB on its own, so on a 0.5 GB service it gets the app OOM-killed. Usage: OcrGuard small|large
 *   small: if OCR is on and we never turned it off before, turn it off and leave a marker on /data.
 *   large: if our marker is there, turn OCR back on and remove the marker.
 * A deployer who turns OCR back on by hand on a small plan is left alone (the marker stays).
 * Waits for Teedy's own migrations to create the T_CONFIG row (first boot), up to 15 minutes.
 */
public class OcrGuard {
    private static final Path MARKER = Path.of("/data/railway-ocr-auto-off");

    public static void main(String[] args) throws Exception {
        boolean small = args.length > 0 && args[0].equals("small");
        String url = System.getenv("DATABASE_URL");
        if (url == null || url.isEmpty()) return;
        for (int i = 0; i < 180; i++) {
            try (Connection c = DriverManager.getConnection(url, System.getenv("DATABASE_USER"), System.getenv("DATABASE_PASSWORD"))) {
                String cur = null;
                try (PreparedStatement s = c.prepareStatement("select CFG_VALUE_C from T_CONFIG where CFG_ID_C = 'OCR_ENABLED'");
                     ResultSet r = s.executeQuery()) {
                    if (r.next()) cur = r.getString(1);
                }
                if (cur != null) {
                    if (small && !Files.exists(MARKER) && "true".equals(cur)) {
                        set(c, "false");
                        Files.writeString(MARKER, "OCR was turned off automatically: the service has less than 900 MB of RAM.\n");
                        System.out.println("[railway-start] OCR turned off: under 900 MB of RAM. Give the service 1 GB or more and redeploy to turn it back on.");
                    } else if (!small && Files.exists(MARKER)) {
                        set(c, "true");
                        Files.delete(MARKER);
                        System.out.println("[railway-start] OCR turned back on: the service now has 900 MB of RAM or more.");
                    }
                    return;
                }
            } catch (java.sql.SQLException e) {
                // Postgres not reachable yet, or Teedy hasn't created its tables yet.
            }
            Thread.sleep(5000);
        }
        System.out.println("[railway-start] OCR guard gave up waiting for the database.");
    }

    private static void set(Connection c, String v) throws java.sql.SQLException {
        try (PreparedStatement s = c.prepareStatement("update T_CONFIG set CFG_VALUE_C = ? where CFG_ID_C = 'OCR_ENABLED'")) {
            s.setString(1, v);
            s.executeUpdate();
        }
    }
}
