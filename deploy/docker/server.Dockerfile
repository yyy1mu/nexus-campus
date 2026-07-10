# syntax=docker/dockerfile:1.7
FROM maven:3.9.11-eclipse-temurin-21 AS build
WORKDIR /workspace

COPY server/pom.xml server/pom.xml
COPY server/src server/src
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -f server/pom.xml clean package -DskipTests -Dmaven.test.skip=true \
    && find server/target -maxdepth 1 -name "*.jar" ! -name "*.original" -exec cp {} /workspace/nexus-campus-server.jar \;

FROM eclipse-temurin:21-jre
WORKDIR /app

RUN groupadd --system nexus \
    && useradd --system --gid nexus --home-dir /app --shell /usr/sbin/nologin nexus

COPY --from=build --chown=nexus:nexus /workspace/nexus-campus-server.jar /app/nexus-campus-server.jar
COPY --chown=nexus:nexus public /public

ENV SPRING_PROFILES_ACTIVE=prod
ENV SERVER_PORT=8080
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/urandom"

EXPOSE 8080

USER nexus:nexus

HEALTHCHECK --interval=15s --timeout=5s --start-period=45s --retries=5 \
    CMD wget --quiet --tries=1 --output-document=/dev/null http://127.0.0.1:8080/api/nexus/agent-health || exit 1

ENTRYPOINT ["java", "-jar", "/app/nexus-campus-server.jar"]
