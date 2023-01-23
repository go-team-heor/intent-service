#!/bin/sh

gunicorn --bind 0.0.0.0:80 --chdir src wsgi:app