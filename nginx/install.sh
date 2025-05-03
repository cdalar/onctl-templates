#!/bin/bash

sudo apt-get update && sudo apt-get install nginx -y

sudo systemctl enable nginx
sudo systemctl start nginx
