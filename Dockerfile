FROM alpine AS build
RUN apk add --no-cache build-base automake autoconf perl git
RUN git clone https://github.com/MarkShulygin/DevOps-2.git /src
WORKDIR /src
COPY . .
RUN aclocal
RUN autoconf
RUN automake --add-missing
RUN ./configure
RUN make

FROM alpine
COPY --from=build /src/devops2 /usr/local/bin/devops2
ENTRYPOINT ["/usr/local/bin/devops2"]

