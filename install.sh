#!/bin/sh
mkdir -p /usr/local/bin
cp speedtest-cli /usr/local/bin
cp bbwifiaptest.pl /usr/local/bin
cp bbwifiaptest.service /etc/systemd/system
systemctl enable bbwifiaptest.service
