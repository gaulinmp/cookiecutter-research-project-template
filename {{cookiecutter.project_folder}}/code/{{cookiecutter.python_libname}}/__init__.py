# STDlib imports
import os

# 3rd party imports
from reslib import config as __config

# current module imports

__root_dir = os.path.dirname(os.path.abspath(__file__))
config = __config.Config(os.path.join(__root_dir, 'globals.py'))
