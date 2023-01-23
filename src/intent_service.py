import os
import io
import json
import string

from snips_nlu import SnipsNLUEngine
from snips_nlu.default_configs import CONFIG_EN

from flask import Flask
from flask import request

CORPUS_FILE = os.getenv('CORPUS_FILE', default="")

with io.open("../data/dataset.json", encoding='utf-8') as f:
    corpus = json.load(f)

nlu_engine = SnipsNLUEngine(config=CONFIG_EN)
nlu_engine.fit(corpus)


app = Flask(__name__)

@app.route("/")
def get_intents():
    text = request.args.get("text")
    text = text.translate(str.maketrans('', '', string.punctuation))
    return nlu_engine.parse(text)

if __name__ == "__main__":
    app.run(host='0.0.0.0')
