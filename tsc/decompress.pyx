cimport numpy as np
import numpy as np
cimport cython
from cpython.mem cimport PyMem_Malloc, PyMem_Free

@cython.cdivision(True)
def decompress_csv(unsigned int ncols,unsigned int nrows, int[:] divides, unsigned char[:] data):
    cdef:
        np.uint64_t i, j, l, n, row, digs
        np.int64_t num, sign, k, d
        unsigned char ch
        np.int64_t[:] last
        np.int8_t[22] temp
        bytes result
        
    n = len(data)
    last = np.zeros(ncols, dtype=np.int64)
    
    # 10 times should be big enough for new csvs
    out = <unsigned char*>PyMem_Malloc(n * 10)
    
    i, j, k, l = 0, 0, 0, 0
    row = 0
    while i < n and row < nrows:
        for j in range(ncols):
            # parse num
            d = divides[j]
            ch = data[i]
            if ch == 45:
                sign = -1
                i += 1
                ch = data[i]
            else:
                sign = 1
            num = 0
            digs = 0
            while 48 <= ch <= 57:
                num = num * 10 + ch - 48
                digs += 1
                i += 1
                if i >= n:
                    break
                ch = data[i]
            num = sign * num + last[j]
            last[j] = num
            
            # write num to out
            if num > 0:
                sign = 1
            else:
                sign = -1
            if last[j] == 0:
                # num = 0, just write
                out[l] = 48
                l += 1
            else:
                # sign
                if sign == -1:
                    out[l] = 45
                    l += 1
                    num = -num

                # itoa
                k = 0
                ch = num % 10
                temp[k] = ch
                k += 1
                num = num // 10
                while num > 0:
                    ch = num % 10
                    temp[k] = ch
                    k += 1
                    num = num // 10
                k -= 1
                
                if d == 0:
                    # int
                    while k >= 0:
                        out[l] = temp[k] + 48
                        k -= 1
                        l += 1
                else:
                    # float
                    if d > k:
                        out[l] = 48
                        l += 1
                        out[l] = 46
                        l += 1
                    while d > k + 1:
                        out[l] = 48
                        l += 1
                        d -= 1
                    while k >= 0:
                        out[l] = temp[k] + 48
                        l += 1
                        if k == d:
                            out[l] = 46
                            l += 1
                        k -= 1
        
            # skip ','
            i += 1
            if j < ncols - 1:
                out[l] = 44
                l += 1
        row += 1
        out[l] = 10
        l += 1
    result = out[:l]
    PyMem_Free(out)
    return result


cpdef np.int64_t[:] decompress_nums(unsigned int ncols, unsigned int nrows, unsigned char[:] data):
    cdef:
        np.uint64_t i, j, n, row, digs
        np.int64_t num, sign, k
        unsigned char ch
        np.int64_t[:] last
        np.int64_t[:] nums
    
    n = len(data)
    last = np.zeros(ncols, dtype=np.int64)
    nums = np.empty(ncols * nrows, dtype=np.int64)
    
    i, j, k = 0, 0, 0
    row = 0
    while i < n and row < nrows:
        for j in range(ncols):
            # parse num
            ch = data[i]
            if ch == 45:
                sign = -1
                i += 1
                ch = data[i]
            else:
                sign = 1
            num = 0
            digs = 0
            while 48 <= ch <= 57:
                num = num * 10 + ch - 48
                digs += 1
                i += 1
                if i >= n:
                    break
                ch = data[i]
            num = sign * num + last[j]
            last[j] = num
            # write num
            nums[k] = num
            k += 1
            # skip ','
            i += 1
        row += 1
    return nums


def decompress_csv_np(unsigned int ncols,unsigned int nrows, list headers, int[:] divides, unsigned char[:] data):
    cdef:
        np.uint32_t i, d
        np.int64_t[:] nums
        np.ndarray arr

    nums = decompress_nums(ncols, nrows, data)
    dtypes = [(name, 'i8' if d == 0 else 'f8') for d, name in zip(divides, headers)]
    arr = np.recarray(nrows, dtypes)
    for i in range(ncols):
        d = divides[i]
        if d == 0:
            arr[headers[i]] = nums[i::ncols]
        else:
            arr[headers[i]] = np.array(nums[i::ncols], 'f8') / (10 ** d)
    return arr


class AttrDict(dict):
    def __init__(self, *args, **kwargs):
        super(AttrDict, self).__init__(*args, **kwargs)
        self.__dict__ = self


def decompress_csv_py(unsigned int ncols,unsigned int nrows, list headers, int[:] divides, unsigned char[:] data):
    cdef:
        np.uint32_t i, j, d
        np.int64_t[:] nums
        np.int64_t num
        list arr = []
        dict dd
        str name

    for j in range(ncols):
        divides[j] = 10 ** divides[j] 
    nums = decompress_nums(ncols, nrows, data)
    for i in range(nrows):
        dd = {}
        for j in range(ncols):
            name = headers[j]
            num = nums[i*ncols+j]
            d = divides[j]
            if d > 0:
                dd[name] = num * 1. / d
            else:
                dd[name] = num
        arr.append(AttrDict(dd))
    return arr


def decompress_np(unsigned int ncols, unsigned int nrows, divs, dtypes,
                  headers, raws, unsigned char[:] data):
    cdef:
        np.uint64_t i, j
        np.int64_t num, sign, k, d
        np.int64_t[:] nums
        np.int32_t[:] divides = np.array(divs, dtype=np.int32)
        np.ndarray out, arr

    nums = decompress_nums(ncols, nrows, data)

    if len(headers) == 0:
        # should be same type, restore to np.ndarray
        type_ = dtypes[0]
        for dtype in dtypes:
            if dtype != type_:
                raise ValueError('array should be same type if no headers!')
        arr = np.asanyarray(nums)
        return arr.astype(type_).reshape((nrows, ncols))
    else:
        # restore to np.recarray, according to dtypes
        arr = np.asanyarray(nums)
        out = np.recarray(nrows, dtype=list(zip(headers, dtypes)))
        j, k = 0, 0
        for i, dt in enumerate(dtypes):
            d = divides[i]
            type_ = np.dtype(dt)
            if np.issubdtype(type_, np.int) \
                    or np.issubdtype(type_, np.float) \
                    or np.issubdtype(type_, np.datetime64) \
                    or np.issubdtype(type_, np.timedelta64):
                out[headers[i]] = arr[j::ncols].astype(dt)
                if d > 1:
                    out[headers[i]] /= d
                j += 1
            else:
                # assign raw data
                out[headers[i]] = np.frombuffer(raws[k], dtype=type_)
                k += 1
        return out
