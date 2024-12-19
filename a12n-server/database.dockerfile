FROM mirror.gcr.io/mysql/mysql-server:8.0

ENV MYSQL_DATABASE=a12nserver
ENV MYSQL_USER=a12nserver
ENV MYSQL_PASSWORD=secret

COPY mysql-schema/*.sql /docker-entrypoint-initdb.d/
