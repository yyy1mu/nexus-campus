FROM maven:3.9.11-eclipse-temurin-21 AS build
WORKDIR /workspace

COPY server/pom.xml server/pom.xml
COPY server/src server/src
RUN mvn -f server/pom.xml clean package -DskipTests -Dmaven.test.skip=true \
    && find server/target -maxdepth 1 -name "*.jar" ! -name "*.original" -exec cp {} /workspace/nexus-campus-server.jar \;

FROM eclipse-temurin:21-jre
WORKDIR /app

COPY --from=build /workspace/nexus-campus-server.jar /app/nexus-campus-server.jar
COPY public /public

ENV SPRING_PROFILES_ACTIVE=prod
ENV SERVER_PORT=8080

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/nexus-campus-server.jar"]
