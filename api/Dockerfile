FROM golang:1.21-alpine AS build

WORKDIR /api
COPY . .

RUN go build -o bin/api

FROM alpine

ENV PORT 8080
ENV DB_NAME 3tier
ENV DB_USER app
ENV DB_PORT 5432
ENV DB_HOST $DB_HOST
ENV DB_PASS $DB_PASS

COPY --from=build /api/bin/api bin/api

CMD [ "bin/api" ]
