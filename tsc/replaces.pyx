import numpy as np
cimport numpy as np
cimport cython

from libc.math cimport log, ceil
from libc.stdlib cimport rand, srand

from .counter cimport ByteArrayCounter


cdef inline double log2(double x):
    return log(x) / log(2.)


@cython.cdivision(True)
cdef inline np.int64_t randint(np.int64_t n):
    return rand() % n


cpdef get_keys(np.int64_t k):
    cdef:
        np.int64_t i, klen
        np.int32_t[32] keys 
    s = ''
    while k > 0:
        s += chr(k % 256)
        k = k // 256
    return s[::-1]


# speeds: ns per byte
cdef np.int64_t paqc_speed = 1442, paqd_speed = 1493
cdef np.int64_t brc_speed = 1927, brd_speed = 8
cdef np.int64_t zc_speed = 167, zd_speed = 13
cdef np.int64_t replace_speed = 5

cpdef get_replaces(bytes delta, float min_reduces=0.005, int max_replaces=50, mode='brotli'):
    srand(0)
    cdef:
        np.int64_t ic, raw_length, length, length2, i, j
        bytes codes = b'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
        unsigned char ch0, ch1, ch2, ch3, ch4, ch5, ch6
        list replaces
        bytes replaced
        np.int32_t[:] keys
        np.int64_t val, k, v
        ByteArrayCounter cc
        np.int64_t ctime, dtime, cspeed, dspeed
        np.int64_t saved_length, cost_replace, saved_bench
        np.int64_t saved_ctime, saved_dtime, total_saved_ctime, total_saved_dtime

    ic = 0
    replaced = delta
    replaces = []
    raw_length = length = len(replaced)
        
    # don't try to optimise if not many value
    if length < 4096:
        return [], replaced

    if mode == 'zlib':
        cspeed, dspeed = zc_speed, zd_speed
    elif mode == 'brotli':
        cspeed, dspeed = brc_speed, brd_speed
    elif mode == 'paq':
        cspeed, dspeed = paqc_speed, paqd_speed
    else:
        raise ValueError('mode {} not supported'.format(mode))

    ctime = cspeed * length
    dtime = dspeed * length
    saved_bench = ctime // 200
    total_saved_ctime = total_saved_dtime = 0

    while True:
        # count char pairs frequency
        length = len(replaced)
        cc = ByteArrayCounter()
        j = 0
        while j < 1000:
            i = randint(length - 7)
            ch0 = replaced[i]
            ch1 = replaced[i+1]
            ch2 = replaced[i+2]
            ch3 = replaced[i+3]
            ch4 = replaced[i+4]
            ch5 = replaced[i+5]
            ch6 = replaced[i+6]
            val = (ch0 << 8) + ch1
            cc.increase(val, 1)
            val = (val << 8) + ch2
            cc.increase(val, 2)
            val = (val << 8) + ch3
            cc.increase(val, 3)
            val = (val << 8) + ch4
            cc.increase(val, 4)
            val = (val << 8) + ch5
            cc.increase(val, 5)
            val = (val << 8) + ch6
            cc.increase(val, 6)
            j += 1

        k, v = cc.most_common(1)[0]
        saved_length = v * length / 1000
        length2 = length - saved_length
        
        cost_replace = length * replace_speed
        saved_ctime = cspeed * saved_length - cost_replace
        saved_dtime = dspeed * saved_length - cost_replace
        total_saved_ctime = cspeed * (raw_length - length) - cost_replace * ic + saved_ctime
        total_saved_dtime = dspeed * (raw_length - length) - cost_replace * ic + saved_dtime

        if length2 < length * (1 - min_reduces):
            if ic >= 5:
                if saved_ctime < saved_bench:
                    break
                if dtime - total_saved_dtime > 2 * dtime:
                    break
                if ic > max_replaces:
                    break
            skeys = get_keys(k)
            replaces.append((skeys, chr(codes[ic])))
            replaced = replaced.replace(skeys.encode('utf-8'), codes[ic:ic+1])
            ic += 1
        else:
            break
    return replaces, replaced
