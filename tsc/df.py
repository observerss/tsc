import math
from array import array

import brotli
import numpy as np
import pandas as pd

from .np import compress as npc, decompress as npd
from .parser import parse_np
from .compress import get_replaces


def compress(df, precision=3):
    headers = df.columns.tolist()
    array = [df[c].values for c in headers]
    nrows = df.shape[0]
    ncols = df.shape[1]
    dtypes, divides, raws, i8n, delta = parse_np(array, precision=precision)
    replaces, replaced = get_replaces(delta)
    header = '{}+{}+{}+{}+{}+{}+'.format(i8n, nrows, headers, dtypes, divides, replaces)
    result = b'+d\x00' + brotli.compress(header.encode('utf-8')
        + b'+'.join([replaced] + [r.tobytes() for r in raws]))
    return result


def decompress(data, format=None):
    if data.startswith(b'+d\x00'):
        data = b'+n\x00' + data[3:]
        array = npd(data)
        return pd.DataFrame(array)
    else:
        raise ValueError('format error')
