FROM alpine
WORKDIR /home/ubuntu/DevOps-2
COPY ./devops2 .
RUN apk add libstdc++
RUN apk add libc6-compat
ENTRYPOINT ["./devops2"]
