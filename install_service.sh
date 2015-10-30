#!/bin/sh
cp speedtest.service /etc/systemd/system
systemctl enable speedtest.service
