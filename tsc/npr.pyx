import numpy as np
cimport numpy as np
cimport cython
from cpython.mem cimport PyMem_Malloc, PyMem_Free

ctypedef np.int64_t[:] i8v
ctypedef np.float32_t[:] f8v

@cython.boundscheck(False)
cpdef parse_np(np.ndarray array, int precision=2):
    cdef:
        tuple headers
        list raws = []
        list dtypes = []
        np.float64_t f
        i8v* i8s
        np.int32_t[:] divides
        np.ndarray a
        np.float64_t[:] aa
        np.int32_t nrows, ncols, i, j, dsize, tempi, i8n = 0, divide = 0
        np.int64_t[:] last
        np.int64_t val, inum
        np.uint8_t[:] delta
        np.int32_t[22] temp
    
    ncols = len(array[0])
    nrows = array.shape[0]
    i8s = <i8v*>PyMem_Malloc((ncols+1)*sizeof(i8v*))
    divides = np.zeros(ncols, dtype=np.int32)
    for i in range(ncols):
        type_ = array.dtype[i]
        name = array.dtype.names[i]
        dtypes.append(type_.name)
        
        a = array.getfield(*array.dtype.fields[name])
        
        if np.issubdtype(type_, np.float):
            print('float')
            aa = a.astype('<f8')
            for i in range(nrows):
                tempi = 0
                f = aa[i] 
                while f != <long>(f):
                    tempi += 1
                    f *= 10 
                    if tempi >= precision:
                        break
                divide = max(divide, tempi)
                if divide >= precision:
                    break
            if divide > 0:
                a = (a.__mul__(10 ** divide))
            i8s[i8n] = a.astype('<i8')
            i8n += 1
        elif np.issubdtpye(type_, np.int) or np.issubdtype(type_, np.bool) or np.issubdtype(np.datetime64) or np.issubdtype(np.timedelta64):
            i8s[i8n] = a.astype('<i8')
            i8n += 1
        else:
            raws.append(a)
            
    headers = array.dtype.names
    dsize = 0
    delta = np.empty(max(1000, nrows * i8n * 16), dtype=np.uint8)
    last = np.zeros(i8n, dtype=np.int64)
    for i in range(nrows):
        for j in range(i8n):
            inum = i8s[j][i]
            i8s[j][i] = inum - last[j]
            last[j] = inum
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
    delta = bytearray(delta[:dsize])
    PyMem_Free(i8s)
    return dtypes, list(divides), headers, raws, i8n, delta
