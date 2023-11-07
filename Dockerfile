FROM python:3.8-slim as base
RUN apt-get update -y \
  && apt-get install -y --no-install-recommends curl gcc g++ \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

FROM base as build
WORKDIR /app
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
RUN pip install --no-warn-script-location "numpy<1.24" spacy concepcy asent langdetect
RUN python -m spacy download en_core_web_sm

# THIS IS RIDICULOUSLY UNSAFE AND NEEDS TO BE FIXED WHEN SNIPS UPDATES THEIR CERTS
RUN pip config set global.trusted-host "resources.snips.ai" --trusted-host=https://resources.snips.ai/
RUN pip install --no-warn-script-location snips-nlu==$SNIPS_VERSION
# RUN sed -i 's/r = requests.get(url)/r = requests.get(url, verify=False)/' /usr/local/lib/python3.7/site-packages/snips_nlu/cli/utils.py
RUN sed -i 's/r = requests.get(url)/r = requests.get(url, verify=False)/' /usr/local/lib/python3.8/site-packages/snips_nlu/cli/utils.py
RUN python -m snips_nlu download en
RUN python -m snips_nlu download-language-entities en
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Python application dependencies 
FROM build as dependencies
WORKDIR /app
COPY requirements.txt requirements.txt
RUN pip install --no-warn-script-location -r requirements.txt

# Update the training dataset
FROM dependencies as training
WORKDIR /app
RUN rm -rf data/
COPY data/ data/
RUN cat data/configs/*.yml > data/dataset.yml
RUN snips-nlu generate-dataset en data/dataset.yml > data/dataset.json

# Run stage
FROM training
# USER gunicorn
WORKDIR /app
COPY src/ src/
COPY --from=training /app/data /app/data 
COPY start-prod.sh /app/start-prod.sh
RUN chmod 777 /app/start-prod.sh
COPY start-dev.sh /app/start-dev.sh
RUN chmod 777 /app/start-dev.sh
# COPY start-dev.sh /app/start-dev.sh
ENV PATH=${PATH}:/usr/local/bin
ARG PORT
EXPOSE ${PORT}
ENTRYPOINT [ "/bin/bash" ]