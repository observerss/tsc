import math
import random
from array import array
from collections import Counter

import brotli
import numpy as np

from .compress import get_replaces
from .decompress import decompress_csv


def get_lines(data, precision=2):
    lines = data.strip().split('\n')
    lines = [line.split(',') for line in lines]
    ncols = len(lines[0])
    nrows = len(lines)
    divides = [1] * ncols
    dd = 10 ** precision
    for i in range(100):
        idx = random.randint(1, nrows - 1)
        vals = lines[idx]
        for i in range(ncols):
            v = float(vals[i])
            d = 1
            while True:
                if v * d % 1 == 0:
                    divides[i] = min(dd, max(divides[i], d))
                    break
                else:
                    d *= 10
    for i in range(1, nrows):
        for j in range(ncols):
            lines[i][j] = round(float(lines[i][j]) * divides[j])
    return ncols, divides, lines


def get_delta(lines, i=1):
    last = lines[i]
    tokens = list([str(x) for x in last])
    ncols = len(last)
    nrows = len(lines)
    for j in range(i+1, nrows):
        line = lines[j]
        if line:
            for i in range(ncols):
                tokens.append(str(line[i] - last[i]))
            last = line
    return bytearray(','.join(tokens).encode('utf-8'))


def compress(data, precision=2):
    """ data should looks like below,
    
    a,b,c
    12,23,12
    12,3,4
    """
    random.seed(1)
    ncols, divides, lines = get_lines(data, precision=precision)
    headers = lines[0]
    delta = get_delta(lines, i=1)
    replaces, replaced = get_replaces(delta)
    header = '{}+{}+{}+{}+'.format(ncols, headers, divides, replaces)
    result = brotli.compress(header.encode('utf-8') + replaced)
    return result


def decompress(data):
    raw = brotli.decompress(data)
    vals = raw.split(b'+')
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