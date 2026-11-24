# Patch carried by this template

`com/sismics/docs/core/util/ConfigUtil.java` is Teedy v1.12's own file with one change:
`getConfigStringValue` opens a short transaction of its own when it is called outside one.

Why: Teedy's background file processing (thumbnails, text extraction, OCR) runs after its
transaction has closed, so reading the `OCR_ENABLED` setting failed and fell back to "on".
The admin's **Settings → Configuration → OCR** switch therefore never stopped OCR of uploads.
On a 0.5 GB service, OCR of a single scanned page (rendered at 300 DPI and upscaled to
3500 px) is enough to run out of memory, so this template needs that switch to work.

The Dockerfile compiles this file against the libraries in Teedy's own WAR and adds the class
to `WEB-INF/classes`, which is loaded before `WEB-INF/lib/docs-core-*.jar`. When Teedy is
bumped, re-copy `ConfigUtil.java` from the new tag and re-apply the change (or drop the patch
once upstream fixes it).
