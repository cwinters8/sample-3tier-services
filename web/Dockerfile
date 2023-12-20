FROM golang:1.21-alpine AS build

WORKDIR /web
COPY . .

RUN go build -o bin/web

FROM alpine

ENV PORT 3000
ENV API_HOST $API_HOST

COPY --from=build /web/index.html ./
COPY --from=build /web/bin/web bin/web

CMD [ "bin/web" ]
