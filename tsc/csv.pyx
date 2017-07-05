import math
import random
from array import array
from collections import Counter

import brotli
import numpy as np

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
    return ','.join(tokens)


def get_replaces(delta):
    # don't try to optimise if not many value
    if len(delta) < 10000:
        return [], delta

    ic = 0
    codes = 'abcdefghijklmnopqrstuvwxyz'
    replaced = delta
    replaces = []
    while True:
        c = Counter(replaced)
        freq5 = [k for k, v in c.most_common(5)]
        length = len(replaced)
        if length < 10:
            break
        cc = Counter()
        for k in range(min(1000, len(delta) // 2)):
            i = random.randint(0, length - 6)
            if replaced[i] in freq5:
                cc[replaced[i:i+3]] += 1
                cc[replaced[i:i+4]] += 1
                cc[replaced[i:i+5]] += 1
                cc[replaced[i:i+6]] += 1

        ccc = Counter()
        entropy1 = 0
        for ch in c:
            prob = c[ch] / length
            entropy1 -= prob * math.log2(prob)
        entropy1 *= length / 8
        
        for k, v in cc.most_common(5):
            chs = set(k)
            entropy2 = 0
            length2 = length - (len(k) - 1) * replaced.count(k)
            for ch in c:
                if ch in chs:
                    prob = (c[ch] - k.count(ch) * v) / length2
                else:
                    prob = c[ch] / length2
                if prob > 0:
                    entropy2 -= prob * math.log2(prob)
            prob = v / length2
            entropy2 -= prob * math.log2(prob)
            entropy2 *= length2 / 8
            
            if (entropy1 - entropy2) / entropy1 > 0.005:
                ccc[k] = entropy1 - entropy2
        if not ccc:
            break
        k, v = ccc.most_common(1)[0]
        replaces.append((k, codes[ic]))
        replaced = replaced.replace(k, codes[ic])
        ic += 1
        if ic > 20:
            break
    return replaces, replaced


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
    result = brotli.compress('{}+{}+{}+{}+{}'.format(
        ncols, headers, divides, replaces, replaced).encode('utf-8'))
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