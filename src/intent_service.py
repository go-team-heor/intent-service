# type: ignore
# pylint: disable=import-error
import os
import io
import json
import string
import logging
import sys
from snips_nlu import SnipsNLUEngine             
from snips_nlu.default_configs import CONFIG_EN  
import spacy
import asent
import concepcy
from langdetect import detect
from flask import Flask
from flask import request

VERSION = os.getenv("VERSION", "0.1")
ENVIRONMENT = os.getenv('ENVIRONMENT', "production")
DEBUG = os.getenv('DEBUG', False)
CORPUS_FILE = os.getenv('CORPUS_FILE', "../data/dataset.json")

# Setup Logger
# ------------
log_level = logging.DEBUG if DEBUG else logging.INFO
logging.basicConfig(level=log_level, stream=sys.stdout)
logger = logging.getLogger()

logger.info(f'HEOR Intent Service v{VERSION}')

# Setup Snips
# -----------
logger.info(f'Loading Snips NLU engine with model at {CORPUS_FILE}')
with io.open(CORPUS_FILE, encoding='utf-8') as f:
    corpus = json.load(f)
nlu_engine = SnipsNLUEngine(config=CONFIG_EN)
nlu_engine.fit(corpus)

# Setup Spacy
# -----------
logger.info(f'Loading SpaCy NLP engine')
nlp = spacy.load("en_core_web_sm")
nlp.add_pipe('sentencizer')
nlp.add_pipe('asent_en_v1')
nlp.add_pipe("concepcy")
logger.debug(f'Loaded SpaCy pipelines: {nlp.pipe_names}')

logger.info('Engines loaded! LFG!')

# Setup Flask
# -----------
app = Flask(__name__)
app.config['DEBUG'] = DEBUG

def analyze_text(text):
    return nlp(text)

def parse_intents(text):
    text = text.translate(str.maketrans('', '', string.punctuation))
    intents = nlu_engine.parse(text)
    
    try:
        intentName = intents.get('intent').get('intentName')
        if intentName == None:
            logger.warning(f'Unable to determine intent, evaluate for training. TEXT: {text}')
    except AttributeError:
        logger.error(f'Invalid or corrupt intent received')

    # if intents.intentName == None:
        # logger.warning(f'No intents found for string {text}')
    return nlu_engine.parse(text)

@app.route("/intents")
def get_intents():
    text = request.args.get("text")
    return parse_intents(text)

@app.route("/analysis")
def get_analysis():
    text = request.args.get("text")
    intents = parse_intents(text)
    analysis = analyze_text(text)
    sentiment = analysis._.polarity.dict()
    concepts = analysis._.relatedto
    # return ""
    return { 
        "language": detect(text), 
        "analysis": analysis.to_json(), 
        "intents": intents,
        "concepts": concepts,
        "sentiment": {key: sentiment[key] for key in [ "negative", "neutral", "positive"]}
        }

if __name__ == "__main__":
    app.run(host='0.0.0.0')

