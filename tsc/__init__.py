import brotli
import pyximport
import numpy as np
import pandas as pd
from array import array
pyximport.install(setup_args={'include_dirs': [np.get_include()]})

from .algo import diff, diff_depth, undiff, undiff_depth
from .converter import (
    parse_csv, parse_df, to_internal,
    parse_internal, to_csv, to_np)


__version__ = '0.2.1'


def get_depth_params(headers):
    if ('ap1' in headers and 'av1' in headers) or \
            ('bp1' in headers and 'bv1' in headers):
        if 'av1' in headers:
            offset = headers.index('av1') - headers.index('ap1')
        else:
            offset = headers.index('bv1') - headers.index('bp1')
        for i, h in enumerate(headers):
            if h.startswith('ap') and h[-1].isdigit():
                start = i
                break
            elif h.startswith('bp') and h[-1].isdigit():
                start = i
                break
        start = start + offset
        end = start + offset
        excludes = array('l')
        for i, h in enumerate(headers):
            if h not in ['timestamp', 'close', 'pre_close', 'pclose'] \
                    and not h[-1].isdigit():
                excludes.append(i)
        return excludes, start, end


def compress_bytes(v, precision=3):
    ncols, nrows, headers, divides, arr = parse_csv(v)
    params = get_depth_params(headers)
    if params:
        arr = diff_depth(ncols, nrows, arr, *params)
    else:
        arr = diff(ncols, nrows, arr)
    data = to_internal(ncols, nrows, arr, headers, divides)
    return brotli.compress(data)


def compress_dataframe(v, precision=3):
    ncols, nrows, headers, divides, arr = parse_df(v)
    params = get_depth_params(headers)
    if params:
        arr = diff_depth(ncols, nrows, arr, *params)
    else:
        arr = diff(ncols, nrows, arr)
    data = to_internal(ncols, nrows, arr, headers, divides)
    return brotli.compress(data)


def compress(v, precision=3):
    if isinstance(v, str):
        v = v.encode('utf-8')

    if isinstance(v, bytes):
        return compress_bytes(v, precision)
    elif isinstance(v, pd.DataFrame):
        return compress_dataframe(v, precision)


def decompress(v, format='df'):
    internal = brotli.decompress(v)
    if b'+' not in internal:
        # format error, return raw internal
        return internal
    else:
        ncols, nrows, headers, divides, arr = parse_internal(internal)
        params = get_depth_params(headers)
        if params:
            arr = undiff_depth(ncols, nrows, arr, *params)
        else:
            arr = undiff(ncols, nrows, arr)
        if format == 'csv':
            return to_csv(ncols, nrows, headers, divides, arr)
        elif format == 'df':
            arr = to_np(ncols, nrows, headers, divides, arr)
            return pd.DataFrame(arr)
        else:
            raise NotImplementedError('format {} not supported'.format(
                fomart))
