import numpy as np
cimport numpy as np
from libc.math cimport round, log
cimport cython
from cpython.mem cimport PyMem_Malloc, PyMem_Free


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef parse_df(df, int precision=3):
    """ returns ncols, nrows, headers, divides, values """
    cdef:
        np.int64_t i, j, ncols, nrows, d
        np.float64_t num
        np.int64_t[:] divides
        np.int64_t[:] ai
        np.float64_t[:, :] vals = df.values

    headers = list(df.columns)
    ncols = len(headers)
    nrows = df.shape[0]
    divides = np.ones(ncols, dtype=np.int64)
    ai = np.empty(ncols*nrows, dtype=np.int64)
    for i in range(nrows):
        for j in range(ncols):
            num = vals[i, j]
            d = 1
            while abs(num - round(num)) > 1e-6:
                d *= 10
                num *= 10
            divides[j] = max(divides[j], d)
    for i in range(nrows):
        for j in range(ncols):
            ai[i * ncols + j] = <np.int64_t>round(vals[i, j] * divides[j])
    return ncols, nrows, headers, divides, ai


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cpdef parse_csv(bytes data, int precision=3):
    """ returns ncols, nrows, headers, divides, values"""
    cdef:
        np.int64_t i, j, k, n, row, size
        np.uint8_t ch
        np.int8_t sign
        np.int64_t ncols, nrows, div, inum, max_num
        np.float64_t num
        np.int64_t[:] divides
        np.float64_t[:] af
        np.int64_t[:] ai
        np.uint8_t[:] csv

    max_num = 2 ** 60 // 10 ** precision // 2
    n = len(data)
    i = data.find(10)
    headers = data[:i].decode('utf-8').split(',')
    ncols = data[:i].count(44) + 1
    nrows = data.count(10) - 1
    csv = bytearray(data)
    divides = np.zeros(ncols, dtype=np.int64)
    af = np.empty(ncols*nrows, dtype=np.float64)
    ai = np.empty(ncols*nrows, dtype=np.int64)

    i += 1
    row = 0
    size = 0
    ch = csv[i]
    while i < n and row < nrows:
        j = 0
        while j < ncols:
            ch = csv[i]
            if ch == 45:
                sign = -1
                i += 1
                ch = csv[i]
            else:
                sign = 1
            num = 0
            div = 0
            while 48 <= ch <= 57:
                num = num * 10 + ch - 48
                i += 1
                if i >= n:
                    break
                ch = csv[i]
            if ch == 46:
                i += 1
                ch = csv[i]
                while 48 <= ch <= 57:
                    if div < precision:
                        num = num * 10 + ch - 48
                        div += 1
                    i += 1
                    if i >= n:
                        break
                    ch = csv[i]

            if sign == -1:
                num = - num
            if div > 0:
                num /= (10 ** div)
                divides[j] = max(divides[j], div)
                
            if num > max_num:
                raise ValueError('too high precision, give up')
            af[size] = num
            size += 1

            # skip ',', '\n'
            if ch == 44:
                pass
            elif ch == 10:
                if j != ncols - 1:
                    raise ValueError(r'csv format error, should be ",", but got "\n"')
            elif i >= n:
                break
            else:  
                raise ValueError(r'csv format error, should be one of ",\n", but got "{}"'.format(chr(ch)))
                
            i += 1
            j += 1

    nrows = size // ncols
    for j in range(ncols):
        divides[j] = 10 ** divides[j]

    for i in range(nrows):
        for j in range(ncols):
            k = i * ncols + j
            inum = <np.int64_t>round(af[k] * divides[j])
            ai[k] = inum
            
    return ncols, nrows, headers, divides, ai


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef to_internal(np.int64_t ncols, np.int64_t nrows, np.int64_t[:] vals,
            headers, np.int64_t[:] divides):
    cdef:
        np.int64_t i, j, size, num, tempi
        np.int8_t[:] temp = np.zeros(32, dtype=np.int8)
        np.uint8_t[:] buff
    
    head = ','.join(headers) + '+' + ','.join([str(d) for d in divides]) + '+'
    size = 0
    buff = np.empty(max(1000, nrows * ncols * 16), dtype=np.uint8)
    last = np.zeros(ncols, dtype=np.int64)
    for j in range(ncols):
        for i in range(nrows):
            num = vals[i * ncols + j]
            if num == 0:
                buff[size] = 48
                size += 1
            else:
                if num < 0:
                    buff[size] = 45
                    size += 1
                    num = - num

                tempi = 0
                temp[0] = num % 10
                num //= 10
                tempi += 1
                while num > 0:
                    temp[tempi] = num % 10
                    num //= 10
                    tempi += 1

                # flush
                while tempi > 0:
                    tempi -= 1
                    buff[size] = temp[tempi] + 48
                    size += 1
            # append comma
            buff[size] = 44
            size += 1
    return bytes(head, 'utf-8') + bytes(buff[:size])


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef parse_internal(bytes data):
    cdef:
        np.int64_t i, j, k, n, nrows, ncols, sign, num, size
        np.uint8_t ch
        np.uint8_t[:] csv
        np.int64_t[:] a, b

    i = data.find(b'+')
    headers = data[:i].decode('utf-8').split(',')
    ncols = len(headers)
    j = data.find(b'+', i+1)
    divides = np.ones(ncols, np.int64)
    for k, x in enumerate(data[i:j].decode('utf-8').split(',')):
        divides[k] = int(x)
    csv = bytearray(data[j+1:])
    n = len(data) - j - 1
    a = np.empty(n // 2, np.int64)
    size = 0
    i = 0
    while i < n:
        ch = csv[i]
        if ch == 45:
            sign = -1
            i += 1
            ch = csv[i]
        else:
            sign = 1
        num = 0
        while 48 <= ch <= 57:
            num = num * 10 + ch - 48
            i += 1
            if i >= n:
                break
            ch = csv[i]

        a[size] = num * sign
        size += 1

        # skip comma
        i += 1
    nrows = size // ncols
    b = np.empty(ncols * nrows, np.int64)
    for j in range(ncols):
        for i in range(nrows):
            b[i * ncols + j] = a[j * nrows + i]
    return ncols, nrows, headers, divides, b


cpdef to_csv(np.int64_t ncols, np.int64_t nrows, headers, np.int64_t[:] divides, np.int64_t[:] arr):
    cdef:
        np.int64_t i, j, l, n, row, digs
        np.int64_t num, sign, k, d, m, z
        unsigned char ch
        np.uint8_t[32] temp
        bytes result
        
    n = ncols * nrows
    # 10 times should be big enough for new csvs
    out = <unsigned char*>PyMem_Malloc(n * 10)
    l = 0
    for j in range(ncols):
        divides[j] = int(round(log(divides[j]) / log(10)))

    for i in range(nrows):
        for j in range(ncols):
            num = arr[i * ncols + j]
            d = divides[j]
            if num > 0:
                sign = 1
            else:
                sign = -1
            if num == 0:
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
                    
                    # if there's ending zero, try eliminate it
                    m = 0
                    while d > 0 and temp[m] == 0:
                        m += 1
                        d -= 1
                    for z in range(k+1-m):
                        temp[z] = temp[z+m]
                    k -= m

                    # do flush
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

            if j < ncols - 1:
                out[l] = 44
                l += 1
            else:
                out[l] = 10
                l += 1
    result = out[:l]
    PyMem_Free(out)
    head = ','.join(headers).encode('utf-8') + b'\n'
    return head + result
            

def get_name(name, used={}):
    if name not in used:
        used[name] = 1
        return name
    else:
        post = used.get(name, 1) + 1
        used[name] = post 
        return name + str(post)


cpdef to_np(np.int64_t ncols, np.int64_t nrows, headers, np.int64_t[:] divides, np.int64_t[:] arr):
    cdef:
        np.int64_t i, d
    dtypes = []
    for i in range(ncols):
        d = divides[i]
        name = get_name(headers[i])
        headers[i] = name
        dtypes.append((name, 'i8' if d == 1 else 'f8')) 
    a = np.recarray(nrows, dtypes)
    for i in range(ncols):
        d = divides[i]
        if d == 1:
            a[headers[i]] = arr[i::ncols]
        else:
            a[headers[i]] = np.array(arr[i::ncols], 'f8') / d
    return a
