import numpy as np
cimport numpy as np

from libc.math cimport round


cpdef parse_csv(bytearray csv, int precision=3):
    """ returns ncols, headers, divides, delta array"""
    cdef:
        np.int64_t i, j, k, n, row, size, dsize, ch, sign
        np.int64_t ncols, nrows, div, inum, tempi, max_num
        np.float64_t num
        np.int32_t[22] temp
        np.int32_t[:] divides
        np.int64_t[:] last
        np.float64_t[:] af
        np.int64_t[:] ai
        np.uint8_t[:] delta

    max_num = 2 ** 60 // 10 ** precision // 2
    n = len(csv)
    i = csv.find(10)
    headers = csv[:i].decode('utf-8').split(',')
    ncols = csv[:i].count(44) + 1
    nrows = csv.count(10)
    divides = np.zeros(ncols, dtype=np.int32)
    last = np.zeros(ncols, dtype=np.int64)
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
            if i == 0:
                ai[k] = inum
            else:
                ai[k] = inum - last[j]
            last[j] = inum
    
    dsize = 0
    delta = np.empty(max(1000, n*2), dtype=np.uint8)
    for i in range(ncols * nrows):
        inum = ai[i]
        if inum == 0:
            delta[dsize] = 48
            dsize += 1
        else:
            if inum < 0:
                delta[dsize] = 45
                dsize += 1
                inum = - inum

            tempi = 0
            temp[0] = inum % 10
            inum //= 10
            tempi += 1
            while inum > 0:
                temp[tempi] = inum % 10
                inum //= 10
                tempi += 1

            # flush to delta
            while tempi > 0:
                tempi -= 1
                delta[dsize] = temp[tempi] + 48
                dsize += 1
        # append comma
        delta[dsize] = 44
        dsize += 1
            
    return ncols, headers, list(divides), bytearray(delta[:dsize])


cpdef parse_np(list la, int precision=3):
    cdef:
        tuple headers
        list raws = []
        list dtypes = []
        np.float64_t f
        np.int32_t[:] divides
        np.ndarray a
        np.float64_t[:] fa
        np.int32_t nrows, ncols, i, j, k, dsize, tempi, i8n = 0, divide
        np.int64_t[:] last, ia, ai
        np.int64_t val, inum, m
        np.uint8_t[:] delta
        np.int32_t[22] temp
    
    ncols = len(la)
    nrows = la[0].shape[0]
    ai = np.empty(ncols*nrows, dtype=np.int64)
    divides = np.zeros(ncols, dtype=np.int32)
    for i in range(ncols):
        a = la[i]
        type_ = a.dtype
        dtypes.append(type_.str)
        
        if np.issubdtype(type_, np.float):
            fa = a.astype('<f8')
            divide = 0
            for j in range(nrows):
                tempi = 0
                f = fa[j] 
                while f != <np.int64_t>(f):
                    tempi += 1
                    f *= 10 
                    if tempi >= precision:
                        break
                divide = max(divide, tempi)
                if divide >= precision:
                    break
            divide = 10 ** divide
            divides[i] = divide
            for j in range(nrows):
                ai[j*ncols+i8n] = <np.int64_t>round(fa[j] * divide)
            i8n += 1
        elif np.issubdtype(type_, np.int) \
                or np.issubdtype(type_, np.datetime64) \
                or np.issubdtype(type_, np.timedelta64):
            ia = a.astype('i8')
            for j in range(nrows):
                ai[j*ncols+i8n] = <np.int64_t>ia[i]
            i8n += 1
        elif type_ is np.object or type_ is np.dtype('S'):
            raise TypeError('cannot compress object/S data, try convert to np.character first')
        else:
            raws.append(a)
            
    dsize = 0
    delta = np.empty(max(1000, nrows * i8n * 16), dtype=np.uint8)
    last = np.zeros(i8n, dtype=np.int64)
    for i in range(nrows):
        for j in range(i8n):
            val = ai[i*ncols+j]
            inum = val - last[j]
            last[j] = val
            if inum == 0:
                delta[dsize] = 48
                dsize += 1
            else:
                if inum < 0:
                    delta[dsize] = 45
                    dsize += 1
                    inum = - inum

                tempi = 0
                temp[0] = inum % 10
                inum //= 10
                tempi += 1
                while inum > 0:
                    temp[tempi] = inum % 10
                    inum //= 10
                    tempi += 1

                # flush to delta
                while tempi > 0:
                    tempi -= 1
                    delta[dsize] = temp[tempi] + 48
                    dsize += 1
            # append comma
            delta[dsize] = 44
            dsize += 1
    return dtypes, list(divides), raws, i8n, bytearray(delta[:dsize])
