FROM golang:latest AS builder

ARG EXPORTER_REPO=https://github.com/rsteenbu/prometheus-klipper-exporter.git
ARG EXPORTER_REF=2c6fa94b9a7ea11908df463d09a551f4f59fc596

WORKDIR /app
RUN git clone ${EXPORTER_REPO} . && git checkout ${EXPORTER_REF}

RUN CGO_ENABLED=0 go build -a -installsuffix cgo -o klipper-exporter .

FROM alpine:latest

COPY --from=builder /app/klipper-exporter /usr/local/bin/klipper-exporter

EXPOSE 9101
ENTRYPOINT ["/usr/local/bin/klipper-exporter"]
