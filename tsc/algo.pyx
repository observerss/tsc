import numpy as np
cimport numpy as np
cimport cython
from .counter cimport Int64HashTable


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef diff(np.int64_t ncols, np.int64_t nrows, np.int64_t[:] vals):
    cdef:
        np.int64_t i, j, k, num
        np.int64_t[:] last

    last = np.zeros(ncols, dtype=np.int64)

    for i in range(nrows):
        for j in range(ncols):
            k = i * ncols + j
            num = vals[k]
            vals[k] = num - last[j]
            last[j] = num
    return vals


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef diff_depth(np.int64_t ncols, np.int64_t nrows, np.int64_t[:] vals,
                 np.int64_t[:] excludes=np.empty(0, np.int64), np.int64_t start=0, np.int64_t end=0):
    """ diff optimized for depth data

    :param excludes: columns that do not diff
    :param start: starting volume index
    :param end: ending volume index
    """
    cdef:
        np.int64_t i, j, k, l, m, num, offset, price, ne, last_volume
        np.int64_t[:] last
        Int64HashTable pvd

    ne = excludes.size
    last = np.zeros(ncols, dtype=np.int64)
    pvd = Int64HashTable(100)
    offset = end - start

    for i in range(nrows):
        for j in range(ncols - 1, -1, -1):
            l = i * ncols + j
            num = vals[l]
            for k in range(ne):
                if j == excludes[k]:
                    # no need to diff
                    break
            else:
                if start <= j < end:
                    # volumes compare according to price
                    price = vals[l - offset]
                    if price in pvd:
                        last_volume = pvd.get_item(price)
                        vals[l] -= last_volume
                    pvd.set_item(price, num)
                else:
                    vals[l] = num - last[j]
            last[j] = num
    return vals


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef undiff(np.int64_t ncols, np.int64_t nrows, np.int64_t[:] vals):
    cdef:
        np.int64_t i, j, k, num
        np.int64_t[:] last

    last = np.zeros(ncols, dtype=np.int64)

    for i in range(nrows):
        for j in range(ncols):
            k = i * ncols + j
            vals[k] += last[j]
            last[j] = vals[k]
    return vals


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef undiff_depth(np.int64_t ncols, np.int64_t nrows, np.int64_t[:] vals,
                 np.int64_t[:] excludes=np.empty(0, np.int64), np.int64_t start=0, np.int64_t end=0):
    """ undiff for depth data

    :param excludes: columns that do not diff
    :param start: starting volume index
    :param end: ending volume index
    """
    cdef:
        np.int64_t i, j, k, l, m, num, offset, price, ne, last_volume
        np.int64_t[:] last
        Int64HashTable pvd

    last = np.zeros(ncols, dtype=np.int64)
    pvd = Int64HashTable(100)
    offset = end - start
    ne = excludes.size

    for i in range(nrows):
        for j in range(ncols):
            l = i * ncols + j
            for k in range(ne):
                if j == excludes[k]:
                    # no need to undiff
                    break
            else:
                if start <= j < end:
                    # volumes compare according to price
                    price = vals[l - offset]
                    if price in pvd:
                        last_volume = pvd.get_item(price)
                        vals[l] += last_volume
                    pvd.set_item(price, vals[l])
                else:
                    vals[l] = last[j] + vals[l]
            last[j] = vals[l]
    return vals
