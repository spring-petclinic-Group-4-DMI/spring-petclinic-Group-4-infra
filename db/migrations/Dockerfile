# syntax=docker/dockerfile:1

FROM alpine:3.20 AS mysql-driver

ARG MYSQL_CONNECTOR_J_VERSION=8.4.0

ADD https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${MYSQL_CONNECTOR_J_VERSION}/mysql-connector-j-${MYSQL_CONNECTOR_J_VERSION}.jar /mysql-connector-j.jar

FROM flyway/flyway:10.22.0-alpine

COPY --from=mysql-driver /mysql-connector-j.jar /flyway/drivers/mysql-connector-j.jar
RUN chmod 0644 /flyway/drivers/mysql-connector-j.jar

COPY *.sql /flyway/sql/
