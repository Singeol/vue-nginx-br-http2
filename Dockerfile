# этап сборки (build stage)
FROM node:lts-alpine as build-stage
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# этап production (production-stage)
FROM ubuntu:20.04 as production-stage
COPY --from=build-stage /app/dist /app
ENV TZ=Europe/Kiev
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN apt update -y && apt install dpkg-dev build-essential gnupg2 git gcc cmake libpcre3 libpcre3-dev zlib1g zlib1g-dev openssl libssl-dev curl unzip -y 
RUN curl -L https://nginx.org/keys/nginx_signing.key | apt-key add -
RUN echo 'deb http://nginx.org/packages/ubuntu/ focal nginx' >> /etc/apt/sources.list.d/nginx.list
RUN echo 'deb-src http://nginx.org/packages/ubuntu/ focal nginx' >> /etc/apt/sources.list.d/nginx.list
RUN apt update -y
WORKDIR /usr/local/src
RUN apt source nginx && apt build-dep nginx -y
RUN git clone --recursive https://github.com/google/ngx_brotli.git
RUN sed -i 's@CFLAGS="" ./configure@CFLAGS="" ./configure --add-module=/usr/local/src/ngx_brotli@' ./nginx-*/debian/rules
RUN mv /usr/local/src/nginx-* /usr/local/src/nginx
WORKDIR /usr/local/src/nginx
RUN dpkg-buildpackage -b -uc -us
RUN dpkg -i /usr/local/src/*.deb
COPY nginx.conf /etc/nginx/nginx.conf
RUN mkdir /etc/systemd/system/nginx.service.d
RUN printf "[Service]\nExecStartPost=/bin/sleep 0.1\n" > /etc/systemd/system/nginx.service.d/override.conf
WORKDIR /
RUN openssl req -x509 -nodes -days 365 -subj "/C=CA/ST=QC/O=Company, Inc./CN=example.com" -addext "subjectAltName=DNS:example.com" -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt;
# RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt
EXPOSE 80 443
CMD ["nginx", "-g", "daemon off;"]
