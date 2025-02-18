FROM golang:1.20-alpine AS build_deps
LABEL org.opencontainers.image.source="https://github.com/ri0day/alidns-webhook-with-role"
RUN apk add --no-cache git

WORKDIR /workspace
ENV GO111MODULE=on
ENV GOOS linux
ENV GOPROXY https://goproxy.cn,direct
COPY go.mod .
COPY go.sum .

RUN go mod download

FROM build_deps AS build

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOPROXY=https://goproxy.cn,direct go build -o webhook -ldflags '-w -extldflags "-static"' .

FROM alpine:3.18

RUN apk add --no-cache ca-certificates

COPY --from=build /workspace/webhook /usr/local/bin/webhook

ENTRYPOINT ["webhook"]
