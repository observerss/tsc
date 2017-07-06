import math
import random
from array import array
from collections import Counter

import brotli
import numpy as np

from .parser import parse_csv
from .compress import get_replaces
from .decompress import decompress_csv


def compress(data, precision=2):
    """ data should looks like below,
    
    a,b,c
    12,23,12
    12,3,4
    """
    if isinstance(data, str):
        data = data.encode('utf-8')
    try:
        data = bytearray(data)
        ncols, headers, divides, delta = parse_csv(data, precision=precision)
        replaces, replaced = get_replaces(delta)
        header = '+csv+{}+{}+{}+{}+'.format(ncols, headers, divides, replaces)
        result = brotli.compress(header.encode('utf-8') + replaced)
    except:
        result = brotli.compress(bytes(data))
    return result


def decompress(data):
    raw = brotli.decompress(data)
    if raw.startswith(b'+csv+'):
        vals = raw[5:].split(b'+')
        ncols, headers, divides, replaces, data = vals
        
        ncols = int(ncols)
        divides = eval(divides, {}, {})
        replaces = eval(replaces, {}, {})
        headers = eval(headers, {}, {})
        
        for k, v in reversed(replaces):
            data = data.replace(v.encode('utf-8'), k.encode('utf-8'))
        headers = ','.join(headers) + '\n'
        nrows = (data.count(b',') + 1) // ncols
        divides = array('i', [int(math.log(d) / math.log(10)) for d in divides])
        return headers + decompress_csv(ncols, nrows, divides, bytearray(data)).decode('utf-8')
    else:
        return raw
