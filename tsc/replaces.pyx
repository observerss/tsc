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
        np.int64_t i = 0, klen
        np.int32_t[:] keys 
    klen = <np.int64_t>ceil(log(k) / log(256))
    keys = np.empty(klen, dtype=np.int32)
    while k > 0:
        keys[i] = k % 256
        k = k // 256
        i += 1
    return keys

    
cdef keys_to_str(np.int32_t[:] keys):
    cdef np.int64_t i = 0
    s = ''
    for i in range(keys.shape[0]):
        s += chr(keys[i])
    return s[::-1]


@cython.boundscheck(False)
@cython.wraparound(False)
cdef count_occurs(unsigned char[:] s, np.int32_t[:] keys):
    cdef:
        np.int64_t i = 0, j, k
        np.int64_t n = len(s), m = keys.shape[0]
        np.int64_t count = 0
        
    while i < n:
        k = i
        j = 0
        while j < m and k < n and s[k] == keys[j]:
            k += 1
            j += 1
        if j == m:
            count += 1
            i = k
        else:
            i += 1
    return count


cdef count_keys(np.int32_t[:] keys, unsigned char ch):
    cdef:
        np.int64_t i = 0, n = keys.shape[0]
        np.int64_t count = 0
    while i < n:
        if keys[i] == ch:
            count += 1
        i += 1
    return count


cpdef get_replaces(bytearray delta):
    srand(0)
    cdef:
        np.int64_t ic, length, length2, i, n, j, found, v
        bytes codes = b'abcdefghijklmnopqrstuvwxyz'
        unsigned char ch, ch0, ch1, ch2, ch3, ch4, ch5, ch6
        np.int64_t[5] freq5
        np.int64_t[6] chs
        list replaces
        bytearray replaced
        np.int32_t[:] keys
        np.int64_t[:] ckeys
        np.int64_t val, k
        ByteArrayCounter c, cc, ccc
        
    # don't try to optimise if not many value
    if len(delta) < 4096:
        return [], delta

    ic = 0
    replaced = delta
    replaces = []
    while True:
        c = ByteArrayCounter()
        c.feed(replaced)
        ckeys = np.empty(c.size(), dtype=np.int64)
        i = 0
        for k, v in c.most_common():
            if i < 5:
                freq5[i] = k
            ckeys[i] = k
            i += 1
        length = len(replaced)
        if length < 1000:
            break

        # count char pairs frequency
        cc = ByteArrayCounter()
        j = 0
        while j < 1000:
            i = randint(length - 7)
            ch0 = replaced[i]
            if ch0 == freq5[0] or ch0 == freq5[1] or ch0 == freq5[2] or ch0 == freq5[3] or ch0 == freq5[4]:
                ch1 = replaced[i+1]
                ch2 = replaced[i+2]
                ch3 = replaced[i+3]
                ch4 = replaced[i+4]
                ch5 = replaced[i+5]
                ch6 = replaced[i+6]
                val = (ch0 << 8) + ch1
                cc.increase(val, 1)
                val = (val << 8) + ch2
                cc.increase(val, 1)
                val = (val << 8) + ch3
                cc.increase(val, 1)
                val = (val << 8) + ch4
                cc.increase(val, 1)
                val = (val << 8) + ch5
                cc.increase(val, 1)
                val = (val << 8) + ch6
                cc.increase(val, 1)
            j += 1

        # compare entropies
        entropy1 = 0
        n = ckeys.shape[0]
        for i in range(n):
            ch = ckeys[i]
            prob = 1. * c.get_item(ch) / length
            entropy1 -= prob * log2(prob)
        entropy1 *= length / 8

        ccc = ByteArrayCounter()
        for k, v in cc.most_common(5):
            lenk = <np.int64_t>ceil(log(k)/log(256))
            keys = get_keys(k)
            entropy2 = 0
            length2 = length - (lenk - 1) * count_occurs(replaced, keys)
            for i in range(n):
                ch = ckeys[i]
                found = count_keys(keys, ch)
                if found:
                    prob = 1. * (c.get_item(ch) - found * v) / length2
                else:
                    prob = 1. * c.get_item(ch) / length2
                if prob > 0:
                    entropy2 -= prob * log2(prob)
            prob = 1. * v / length2
            entropy2 -= prob * log2(prob)
            entropy2 *= length2 / 8
            
            if (entropy1 - entropy2) / entropy1 > 0.005:
                ccc.set_item(k, <np.int64_t>(entropy1 - entropy2))
        if not ccc:
            break
        k, v = ccc.most_common(1)[0]
        replaces.append((keys_to_str(get_keys(k)), chr(codes[ic])))
        replaced = replaced.replace(keys_to_str(get_keys(k)).encode('utf-8'), codes[ic:ic+1])
        ic += 1
        if ic > 5:
            break
    return replaces, replaced
