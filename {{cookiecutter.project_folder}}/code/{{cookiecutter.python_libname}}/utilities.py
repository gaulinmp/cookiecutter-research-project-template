# STDlib imports
import re as __re
import logging as __logging

# 3rd party imports
import numpy as np
# import pandas as pd

# current module imports

# Local logger
__logger = __logging.getLogger(__name__)
# logger.setLevel(GLOB.LOG_LEVEL)


def write_stata_file(df, filepath):
    """Write dataframe to filepath.
    Does basic checking for the common errors like missing strings (`None` instead of `""`) and casting bool to 1/0.

    Args:
        df (DataFrame): DataFrame to write to `filepath`
        filepath (str, Path): File path to write out to

    Returns:
        str: Filepath that was written out to.
    """
    df=df.copy()

    for c in df.select_dtypes(include=['object', 'bool']).columns:
        if not (set(df[c].unique()) - {True, False}):
            __logger.info("write_stata_file: %s is True/False column. Making 0/1.", c)
            df[c] = df[c].astype(int)
        elif not (set(df[c].unique()) - {True, False, np.nan}):
            __logger.info("write_stata_file: %s is True/False/Null column. Making 0/1.", c)
            df[c] = df[c].astype(float)
        elif not (set(df[c].fillna(False).unique()) - {True, False}):
            __logger.info("write_stata_file: %s is True/False/Null filled column. Making 0/1.", c)
            df[c] = df[c].astype(float)
        elif not (set(df[c].fillna(False).unique()) - {True, False, np.nan}):
            __logger.info("write_stata_file: %s is True/False/Null filled column nan. Making 0/1.", c)
            df[c] = df[c].astype(float)

        try:
            max_len = max(df.loc[df[c].notnull(), c].apply(len))
            if max_len > 1023:
                __logger.warning("Column %s has max string len == %d, dropping", c, max_len)
                del df[c]
        except:
            # len didn't work? Ignore. Probably bigger problems waiting below.
            pass

    date_cols = {k: 'td' for k in df.select_dtypes(include='datetime64').columns}

    for c in df.select_dtypes(include='object').columns:
        try:
            df[c].str.encode('latin-1')
            __logger.info("write_stata_file: %s is a string column, filling missing with ''", c)
            df[c] = df[c].fillna('')
        except AttributeError:
            pass
        except UnicodeEncodeError:
            __logger.warning("write_stata_file: %s has non latin-1 encodable characters", c)
            df[c] = df[c].str.encode('latin-1', errors='ignore').str.decode('latin-1', errors='ignore').fillna('')

    df.to_stata(filepath,
                write_index=False,
                version=117,
                convert_dates=date_cols)

    return filepath
