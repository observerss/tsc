cimport numpy as np
cimport cython
from cpython.mem cimport PyMem_Malloc, PyMem_Free

@cython.cdivision(True)
def decompress_csv(unsigned int ncols,unsigned int nrows, int[:] divides, unsigned char[:] data):
    cdef:
        unsigned int i, j, l, n, row, digs
        int num, sign, k, d
        unsigned char ch
        int[:] last
        unsigned int[11] temp
        bytes result
        
    n = len(data)
    last = np.zeros(ncols, dtype=np.int32)
    
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
