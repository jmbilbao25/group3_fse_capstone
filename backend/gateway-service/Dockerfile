FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Copy the pre-built Spring Boot executable JAR
COPY target/gateway-service-1.0.0-SNAPSHOT.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]
