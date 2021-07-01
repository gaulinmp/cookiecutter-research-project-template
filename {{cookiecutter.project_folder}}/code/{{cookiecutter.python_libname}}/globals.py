# STDlib imports
import os
import logging

# 3rd party imports

# current module imports


LOG_LEVEL = logging.INFO


# ██████╗  █████╗ ████████╗██╗  ██╗███████╗
# ██╔══██╗██╔══██╗╚══██╔══╝██║  ██║██╔════╝
# ██████╔╝███████║   ██║   ███████║███████╗
# ██╔═══╝ ██╔══██║   ██║   ██╔══██║╚════██║
# ██║     ██║  ██║   ██║   ██║  ██║███████║
# ╚═╝     ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝
try:
    # If importing from reslib.config, config_path is in global scope,
    # and points to this file
    __moduledir = os.path.dirname(os.path.abspath(config_path))
except NameError:
    # If config_path is missing, then this file is being imported directly,
    # so __file__ will exist.
    __moduledir = os.path.dirname(os.path.abspath(__file__))

ROOT_DIR = os.path.abspath(os.path.join(__moduledir, "../" * 2))

DATA_DIR = os.path.join(ROOT_DIR, "data")
DATA_DIR_EXTERNAL = os.path.join(DATA_DIR, "external")
DATA_DIR_INTERIM = os.path.join(DATA_DIR, "interim")
DATA_DIR_FINAL = os.path.join(DATA_DIR, "final")
CACHE_PATH = os.path.join(DATA_DIR_INTERIM, "cache")

MODEL_DIR = os.path.join(ROOT_DIR, "models")

OUTPUT_DIR = os.path.join(ROOT_DIR, "output")
TABLE_DIR = os.path.join(OUTPUT_DIR, 'tables')
FIGURE_DIR = os.path.join(OUTPUT_DIR, 'figures')
TABLE_DIR_OVERLEAF = os.path.expanduser("~/Dropbox/Apps/Overleaf/{{ cookiecutter.project_folder }}/tables")
FIGURE_DIR_OVERLEAF = os.path.expanduser("~/Dropbox/Apps/Overleaf/{{ cookiecutter.project_folder }}/figures")

ERROR_DIR = os.path.join(OUTPUT_DIR, "error")



# ██████╗  █████╗ ████████╗ █████╗
# ██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗
# ██║  ██║███████║   ██║   ███████║
# ██║  ██║██╔══██║   ██║   ██╔══██║
# ██████╔╝██║  ██║   ██║   ██║  ██║
# ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝
# Data settings
COMPRESSION = "gzip"


# ███████╗███████╗ ██████╗██████╗ ███████╗████████╗
# ██╔════╝██╔════╝██╔════╝██╔══██╗██╔════╝╚══██╔══╝
# ███████╗█████╗  ██║     ██████╔╝█████╗     ██║
# ╚════██║██╔══╝  ██║     ██╔══██╗██╔══╝     ██║
# ███████║███████╗╚██████╗██║  ██║███████╗   ██║
# ╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚══════╝   ╚═╝
# Load password file for wrds, alternatively set the environment variables externally
for pwd_path in ("~/Dropbox/wrds.pwd", "~/wrds.pwd"):
    try:
        with open(os.path.expanduser(pwd_path), "r", encoding="utf-8") as fh:
            wrds_user, wrds_password = fh.read().strip().split("\n")
            os.environ["WRDS_USER"] = wrds_user
            os.environ["WRDS_PASSWORD"] = wrds_password
    except FileNotFoundError:
        continue
