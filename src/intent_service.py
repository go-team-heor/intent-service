# type: ignore
# pylint: disable=import-error
import os
import io
import json
import string
from snips_nlu import SnipsNLUEngine             
from snips_nlu.default_configs import CONFIG_EN  
import spacy
import asent
import concepcy
from langdetect import detect
from flask import Flask
from flask import request

app = Flask(__name__)
app.config['DEBUG'] = True

CORPUS_FILE = os.getenv('CORPUS_FILE', default="")
with io.open("../data/dataset.json", encoding='utf-8') as f:
    corpus = json.load(f)

nlu_engine = SnipsNLUEngine(config=CONFIG_EN)
nlu_engine.fit(corpus)

nlp = spacy.load("en_core_web_sm")
nlp.add_pipe('sentencizer')
nlp.add_pipe('asent_en_v1')
nlp.add_pipe("concepcy")

print(nlp.pipe_names)

def analyze_text(text):
    return nlp(text)

def parse_intents(text):
    text = text.translate(str.maketrans('', '', string.punctuation))
    return nlu_engine.parse(text)

@app.route("/api/intents")
def get_intents():
    text = request.args.get("text")
    return parse_intents(text)

@app.route("/api/analysis")
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
