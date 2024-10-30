
# 拆分基础镜像： docker/dockerfile
# 基础镜像，按照季度，月度更新。不影响应用镜像的构建。

FROM pythonstock/pythonstock:base-2023-06 as builder

# 拷贝本地文件到目录
COPY . /data

# service
FROM docker.io/python:3.8-slim-bullseye

# https://opsx.alibaba.com/mirror
# 使用阿里云镜像地址。修改debian apt 更新地址，pip 地址，设置时区。
# 设置debian的镜像源
RUN echo "deb http://mirrors.aliyun.com/debian/ bullseye main non-free contrib" > /etc/apt/sources.list && \
echo "deb-src http://mirrors.aliyun.com/debian/ bullseye main non-free contrib" >> /etc/apt/sources.list && \
echo "deb http://mirrors.aliyun.com/debian-security/ bullseye-security main" >> /etc/apt/sources.list && \
echo "deb-src http://mirrors.aliyun.com/debian-security/ bullseye-security main" >> /etc/apt/sources.list && \
echo "deb http://mirrors.aliyun.com/debian/ bullseye-updates main non-free contrib" >> /etc/apt/sources.list && \
echo "deb-src http://mirrors.aliyun.com/debian/ bullseye-updates main non-free contrib" >> /etc/apt/sources.list && \
echo "deb http://mirrors.aliyun.com/debian/ bullseye-backports main non-free contrib" >> /etc/apt/sources.list && \
echo "deb-src http://mirrors.aliyun.com/debian/ bullseye-backports main non-free contrib" >> /etc/apt/sources.list && \
echo  "[global]\n\
trusted-host=mirrors.aliyun.com\n\
index-url=http://mirrors.aliyun.com/pypi/simple" > /etc/pip.conf && \
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

#增加语言utf-8
ENV LANG=zh_CN.UTF-8
ENV LC_CTYPE=zh_CN.UTF-8
ENV LC_ALL=C
ENV PYTHONPATH=/data/stock

WORKDIR /data

#add cron sesrvice.
#每分钟，每小时1分钟，每天1点1分，每月1号执行
RUN mkdir -p /etc/cron.minutely && mkdir -p /etc/cron.hourly && mkdir -p /etc/cron.monthly && mkdir -p /var/spool/cron/crontabs && \
    echo "SHELL=/bin/sh \n\
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin \n\
# min   hour    day     month   weekday command \n\
*/1     *       *       *       *       /bin/run-parts /etc/cron.minutely \n\
10       *       *       *       *       /bin/run-parts /etc/cron.hourly \n\
30       16       *       *       *       /bin/run-parts /etc/cron.daily \n\
30       17       1,10,20       *       *       /bin/run-parts /etc/cron.monthly \n" > /var/spool/cron/crontabs/root && \
    chmod 600 /var/spool/cron/crontabs/root


#增加服务端口就两个 6006 8500 9001
EXPOSE 8888 9999


# 直接使用基础镜像然后拷贝 site-packages 安装包即可。
COPY --from=builder /data/jobs /data/stock/jobs
COPY --from=builder /data/libs /data/stock/libs
COPY --from=builder /data/web /data/stock/web
COPY --from=builder /data/supervisor /data/supervisor
# 拷贝二进制文件。
COPY --from=builder /usr/local/bin/supervisord /usr/local/bin/supervisord
COPY --from=builder /usr/lib/x86_64-linux-gnu/libmariadb.so.3 /usr/lib/x86_64-linux-gnu/libmariadb.so.3

# 拷贝 cron 定时任务：
COPY --from=builder /data/jobs/cron.minutely /etc/cron.minutely
COPY --from=builder /data/jobs/cron.hourly /etc/cron.hourly
COPY --from=builder /data/jobs/cron.daily /etc/cron.daily
COPY --from=builder /data/jobs/cron.monthly /etc/cron.monthly

# 拷贝类库
COPY --from=builder /usr/local/lib/python3.8/site-packages /usr/local/lib/python3.8/site-packages

RUN mkdir -p /data/logs && ls /data/stock/ && chmod 755 /data/stock/jobs/run_* &&  \
    chmod 755 /etc/cron.minutely/* && chmod 755 /etc/cron.hourly/* && \
    chmod 755 /etc/cron.daily/* && chmod 755 /etc/cron.monthly/*

ENTRYPOINT ["supervisord","-n","-c","/data/supervisor/supervisord.conf"]