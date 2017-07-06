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


def compress(data, prec=3):
    if isinstance(data, str) or isinstance(data, bytes):
        return csvc(data, prec)
    elif isinstance(data, np.ndarray):
        return npc(data, prec)
    elif isinstance(data, pd.DataFrame):
        return dfd(data, prec)


def decompress(data):
    if data.startswith(b'+c\x00'):
        return csvd(data)
    elif data.startswith(b'+n\x00'):
        return npd(data)
    elif data.startswith(b'+d\x00'):
        return dfd(data)
    else:
        return brotli.decompress(data)
