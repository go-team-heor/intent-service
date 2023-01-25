#!/bin/sh

gunicorn --bind 0.0.0.0:8080 --reload --chdir src wsgi:app