#!/bin/sh

gunicorn --bind 0.0.0.0:8080 --chdir src wsgi:app