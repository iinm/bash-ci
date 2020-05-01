FROM alpine:latest
RUN apk --no-cache add bash curl jq git make shellcheck busybox gawk ncurses
