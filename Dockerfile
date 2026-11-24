# Teedy for Railway: the official image, pinned by version and digest.
# Upstream: https://github.com/sismics/docs (GPL-2.0)
FROM sismics/docs:v1.12@sha256:29ce750d44fd7de8ab995d77aa2bb50978f4ba0862e6aa827bf67517d8758c7b

# Two tiny helpers, compiled against the libraries Teedy itself ships in its WAR:
# - HashPassword turns ADMIN_PASSWORD into the bcrypt hash Teedy expects in DOCS_ADMIN_PASSWORD_INIT;
# - OcrGuard turns OCR off on services with less than 900 MB of RAM (and back on above it).
# The http-forwarded module makes Jetty trust Railway's X-Forwarded-* headers (https links).
COPY HashPassword.java OcrGuard.java /opt/railway/
RUN mkdir -p /opt/railway/lib \
 && cd /opt/railway/lib \
 && unzip -q -j /app/webapps/docs.war 'WEB-INF/lib/bcrypt-*.jar' 'WEB-INF/lib/bytes-*.jar' 'WEB-INF/lib/postgresql-*.jar' \
 && javac -d /opt/railway -cp '/opt/railway/lib/*' /opt/railway/HashPassword.java /opt/railway/OcrGuard.java \
 && cd /app && java -jar /opt/jetty/start.jar --add-modules=http-forwarded >/dev/null

# Upstream fix carried by this template (see patch/README.md): background file processing
# ignored the "OCR enabled" setting. The patched ConfigUtil goes into the WAR's WEB-INF/classes,
# which the servlet container loads before WEB-INF/lib/docs-core-*.jar.
COPY patch /opt/railway/patch
RUN mkdir -p /tmp/war /tmp/out/WEB-INF/classes \
 && cd /tmp/war && unzip -q /app/webapps/docs.war 'WEB-INF/lib/*' \
 && javac -nowarn -d /tmp/out/WEB-INF/classes -cp '/tmp/war/WEB-INF/lib/*' \
      /opt/railway/patch/com/sismics/docs/core/util/ConfigUtil.java \
 && cd /tmp/out && jar uf /app/webapps/docs.war WEB-INF/classes/com/sismics/docs/core/util/ \
 && rm -r /tmp/war /tmp/out

COPY railway-start.sh /opt/railway/railway-start.sh
RUN chmod 755 /opt/railway/railway-start.sh

# Railway routes the public domain to $PORT; /data is the Railway volume.
ENV PORT=8080 \
    OMP_THREAD_LIMIT=1

WORKDIR /app
ENTRYPOINT ["/opt/railway/railway-start.sh"]
