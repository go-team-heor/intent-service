FROM python:3.7-slim as base
RUN apt-get update -y \
  && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends curl \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Build-time metadata as defined at http://label-schema.org
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
ARG SNIPS_VERSION=0.20.2
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="Snips NLU docker base image" \
      org.label-schema.description="This docker image contains the latest Snips-AI NLU engine with all language resources preloaded." \
      org.label-schema.url="https://wuabit.com/" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/wuabit/snips-nlu-docker" \
      org.label-schema.vendor="Wuabit" \
      org.label-schema.version="${VERSION}_${SNIPS_VERSION}" \
      org.label-schema.schema-version="1.0"

RUN pip install --upgrade pip

# THIS IS RIDICULOUSLY UNSAFE AND NEEDS TO BE FIXED WHEN SNIPS UPDATES THEIR CERTS
RUN pip config set global.trusted-host "resources.snips.ai" --trusted-host=https://resources.snips.ai/
RUN pip install snips-nlu==$SNIPS_VERSION
RUN sed -i 's/r = requests.get(url)/r = requests.get(url, verify=False)/' /usr/local/lib/python3.7/site-packages/snips_nlu/cli/utils.py
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
RUN python -m snips_nlu download en
RUN python -m snips_nlu download-language-entities en

# Python application dependencies 
FROM base as setup
RUN adduser gunicorn --shell /bin/bash
USER gunicorn
WORKDIR /home/gunicorn
COPY --chown=gunicorn:gunicorn requirements.txt requirements.txt
COPY --chown=gunicorn:gunicorn src/ src/
RUN pip install -r requirements.txt

# Update the training dataset
FROM setup as training
USER gunicorn
WORKDIR /home/gunicorn

RUN rm -rf data/
COPY --chown=gunicorn:gunicorn data/ data/
RUN cat data/configs/*.yml > data/dataset.yml
RUN snips-nlu generate-dataset en data/dataset.yml > data/dataset.json

# Run stage
FROM training
USER root
WORKDIR /home/gunicorn
COPY --from=setup /home/gunicorn/src/ /home/gunicorn/src
COPY --from=training /home/gunicorn/data /home/gunicorn/data 
COPY start-prod.sh /home/gunicorn/start-prod.sh
ENV PATH=${PATH}:/home/gunicorn/.local/bin
ENTRYPOINT [ "/bin/bash" ]
EXPOSE 8080
# ENTRYPOINT [ "/bin/bash gunicorn --bind 0.0.0.0:80 --chdir src wsgi:app" ]
CMD [ "./start-prod.sh" ]