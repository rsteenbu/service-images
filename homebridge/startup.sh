#!/bin/bash

#
# Docker Homebridge Custom Startup Script - homebridge/homebridge
#
# This script can be used to customise the environment and will be executed as
# the root user each time the container starts.
#
# Example installing packages:
#
# apt-get update
# apt-get install -y python3
#
npm install homebridge-http-switch
npm install homebridge-http-garagedoorcontroller
npm install homebridge-cmdswitch2

apt-get update
apt-get install -y vim
apt-get install -y python3-full
python3 -m venv /python-venv
/python-venv/bin/python -m pip install laiarturs-ros-api
