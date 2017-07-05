from khash cimport *
import numpy as np


cdef class HashTable:
    pass


cdef class Int64HashTable(HashTable):
    cdef kh_int64_t *table

    def __cinit__(self, size_hint=1):
        self.table = kh_init_int64()
        if size_hint is not None:
            kh_resize_int64(self.table, size_hint)

    def __len__(self):
        return self.table.size

    def __dealloc__(self):
        if self.table is not NULL:
            kh_destroy_int64(self.table)
            self.table = NULL

    def __contains__(self, object key):
        cdef khiter_t k
        k = kh_get_int64(self.table, key)
        return k != self.table.n_buckets

    def __bool__(self):
        return self.table.size > 0

    def sizeof(self, deep=False):
        """ return the size of my table in bytes """
        return self.table.n_buckets * (sizeof(int64_t) + # keys
                                       sizeof(size_t) + # vals
                                       sizeof(uint32_t)) # flags

    cpdef size(self):
        return self.table.size

    cpdef get_item(self, int64_t val):
        cdef khiter_t k
        k = kh_get_int64(self.table, val)
        if k != self.table.n_buckets:
            return self.table.vals[k]
        else:
            raise KeyError(val)

    cpdef set_item(self, int64_t key, Py_ssize_t val):
        cdef:
            khiter_t k
            int ret = 0

        k = kh_put_int64(self.table, key, &ret)
        self.table.keys[k] = key
        if kh_exist_int64(self.table, k):
            self.table.vals[k] = val
        else:
            raise KeyError(key)
            
    def __getitem__(self, key):
        assert isinstance(key, int), 'key must be int, but got {}'.format(type(key))
        return self.get_item(key)
    
    def __setitem__(self, key, value):
        assert isinstance(key, int), 'key must be int, but got {}'.format(type(key))
        assert isinstance(value, int), 'value must be int, but got {}'.format(type(value))
        self.set_item(key, value)

            
cdef class ByteArrayCounter(Int64HashTable):
        
    cpdef feed(self, unsigned char[:] data):
        cdef:
            unsigned int i, n
            unsigned char ch
        n = len(data)
        for i in range(n):
            ch = data[i]
            self.increase(ch, 1)
        return n
    
    cpdef increase(self, int64_t key, Py_ssize_t val):
        cdef:
            khiter_t k
            int ret = 0

        k = kh_get_int64(self.table, key)
        if k == self.table.n_buckets:
            # create new item
            k = kh_put_int64(self.table, key, &ret)
            self.table.keys[k] = key
            if kh_exist_int64(self.table, k):
                self.table.vals[k] = val
            else:
                raise KeyError(key)
        else:
            self.table.vals[k] += val
            
    cpdef most_common(self, Py_ssize_t size=0):
        cdef:
            unsigned int i
            long idx
            khiter_t k
            int64_t[:] keys = np.empty(self.table.size, dtype=np.int64)
            int64_t[:] vals = np.empty(self.table.size, dtype=np.int64)
            long[:] idxs
        if size == 0:
            size = self.table.size
        i = 0
        for k in range(self.table.n_buckets):
            if kh_exist_int64(self.table, k):
                vals[i] = self.table.vals[k]
                keys[i] = self.table.keys[k]
                i += 1
        idxs = np.argsort(vals)[::-1][:size]
        result = []
        size = idxs.shape[0]
        for i in range(size):
            idx = idxs[i]
            result.append((keys[idx], vals[idx]))
        return result
