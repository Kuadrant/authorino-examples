FROM mirror.gcr.io/library/alpine:latest

RUN apk update && apk add --no-cache bash curl

WORKDIR /usr/src/app

COPY run run

CMD ["/bin/bash"]
