FROM maven:3.9-eclipse-temurin-21-alpine AS builder
WORKDIR /build
COPY . .
RUN rm -f .mvn/jvm.config
RUN mvn clean package -DskipTests -pl ledger-mutation-engine -am

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /build/ledger-mutation-engine/target/ledger-mutation-engine-1.0.0-SNAPSHOT.jar app.jar
EXPOSE 8082
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]
