import at.favre.lib.crypto.bcrypt.BCrypt;

/** Reads a password from the ADMIN_PASSWORD environment variable and prints its bcrypt hash. */
public class HashPassword {
    public static void main(String[] args) {
        String pw = System.getenv("ADMIN_PASSWORD");
        if (pw == null || pw.isEmpty()) {
            System.err.println("ADMIN_PASSWORD is empty");
            System.exit(1);
        }
        System.out.print(BCrypt.withDefaults().hashToString(10, pw.toCharArray()));
    }
}
