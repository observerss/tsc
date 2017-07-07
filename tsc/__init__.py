import brotli
import pyximport
import numpy as np
import pandas as pd
from os.path import join, dirname, abspath

klib_dir = abspath(join(dirname(__file__), 'klib'))
pyximport.install(setup_args={'include_dirs': [klib_dir, np.get_include()]})


from .np import compress as npc, decompress as npd
from .df import compress as dfc, decompress as dfd
from .csv import compress as csvc, decompress as csvd


def compress(data, precision=3):
    if isinstance(data, str) or isinstance(data, bytes):
        return csvc(data, precision)
    elif isinstance(data, np.ndarray):
        return npc(data, precision)
    elif isinstance(data, pd.DataFrame):
        return dfd(data, precision)


def decompress(data, format=None):
    if data.startswith(b'+c\x00'):
        return csvd(data, format)
    elif data.startswith(b'+n\x00'):
        return npd(data, format)
    elif data.startswith(b'+d\x00'):
        return dfd(data, format)
    else:
        return brotli.decompress(data)
