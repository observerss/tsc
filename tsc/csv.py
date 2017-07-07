import math
import random
from array import array
from collections import Counter

import brotli
import numpy as np

from .parser import parse_csv
from .compress import get_replaces
from .decompress import decompress_csv, decompress_csv_np, decompress_csv_py


def compress(data, precision=3):
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
        header = '{}+{}+{}+{}+'.format(ncols, headers, divides, replaces)
        result = b'+c\x00' + brotli.compress(header.encode('utf-8') + replaced)
    except:
        import traceback
        traceback.print_exc()
        result = brotli.compress(bytes(data))
    return result


def decompress(data, format=None):
    if data.startswith(b'+c\x00'):
        if format is None:
            format = 'csv'
        raw = brotli.decompress(data[3:])
        vals = raw.split(b'+')
        ncols, headers, divides, replaces, data = vals
        
        ncols = int(ncols)
        divides = eval(divides, {}, {})
        replaces = eval(replaces, {}, {})
        headers = eval(headers, {}, {})
        if format != 'csv' and len(set(headers)) != len(headers):
            raise ValueError('headers have same name! can only decompress to csv format')
        
        for k, v in reversed(replaces):
            data = data.replace(v.encode('utf-8'), k.encode('utf-8'))
        nrows = (data.count(b',') + 1) // ncols
        divides = array('i', [math.ceil(math.log(d) / math.log(10)) for d in divides])

        if format == 'csv':
            headers = (','.join(headers) + '\n').encode('utf-8')
            return headers + decompress_csv(ncols, nrows, divides, bytearray(data))
        elif format == 'np':
            return decompress_csv_np(ncols, nrows, headers, divides, bytearray(data))
        elif format == 'py':
            return decompress_csv_py(ncols, nrows, headers, divides, bytearray(data))
        else:
            raise ValueError('format "{}" unknown'.format(format))
    else:
        return brotli.decompress(raw)
