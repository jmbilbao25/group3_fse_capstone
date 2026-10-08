FROM maven:3.9-eclipse-temurin-21-alpine AS builder
WORKDIR /build
COPY pom.xml ./
COPY common-contracts ./common-contracts
COPY gateway-service ./gateway-service
RUN mvn clean package -DskipTests -pl gateway-service -am

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /build/gateway-service/target/gateway-service-1.0.0-SNAPSHOT.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]
