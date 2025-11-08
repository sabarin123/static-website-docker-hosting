# 1️⃣ Use Eclipse Temurin JDK 17 runtime as base image
FROM eclipse-temurin:17-jre-jammy
# 2️⃣ Argument to locate the JAR file
ARG JAR_FILE=target/*.jar
# 3️⃣ Copy the JAR file into the container
copy ${JAR_FILE} app.jar
# 4️⃣ Expose port 8080 for external access
EXPOSE 8080
# 5️⃣ Define the command to run the app
ENTRYPOINT ["java","-jar","/app.jar"]