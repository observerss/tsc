import math
from array import array

import brotli
import numpy as np

from .parser import parse_np
from .compress import get_replaces
from .decompress import decompress_np


def compress(array, precision=3):
    if isinstance(array, np.recarray):
        nrows = array.shape[0]
        headers = array.dtype.names
        array = [array[name] for name in headers]
    elif isinstance(array, np.ndarray):
        if array.ndim != 2:
            raise TypeError('wrong dim')
        headers = []
        nrows = array.shape[0]
        array = [array[:, i] for i in range(array.shape[1])]
    else:
        raise TypeError('wrong type')
    try:
        ncols = len(array)
        dtypes, divides, raws, i8n, delta = parse_np(array, precision=precision)
        replaces, replaced = get_replaces(delta)
        header = '{}+{}+{}+{}+{}+{}+'.format(i8n, nrows, headers, dtypes, divides, replaces)
        result = b'+n\x00' + brotli.compress(header.encode('utf-8')
            + b'+'.join([replaced] + [r.tobytes() for r in raws]))
    except:
        result = b'+n\x01' + brotli.compress(str(array.dtype.descr).encode('utf-8') + b'+' + array.tobytes())
    return result


def decompress(data, format=None):
    if data.startswith(b'+n\x00'):
        raw = brotli.decompress(data[3:])
        vals = raw.split(b'+')
        ncols, nrows, headers, dtypes, divides, replaces, data, *raws = vals
        
        ncols = int(ncols)
        nrows = int(nrows)
        dtypes = eval(dtypes, {}, {})
        divides = eval(divides, {}, {})
        replaces = eval(replaces, {}, {})
        headers = eval(headers, {}, {})
        
        for k, v in reversed(replaces):
            data = data.replace(v.encode('utf-8'), k.encode('utf-8'))

        return decompress_np(ncols, nrows, divides, dtypes, headers, raws, bytearray(data))
    elif data.startswith(b'+n\x01'):
        raw = brotli.decompress(data[3:])
        dtypes, data = raw.split(b'+')
        dtypes = eval(dtypes, {}, {})
        return np.frombuffer(data, dtypes)
    else:
        return brotli.decompress(data)
