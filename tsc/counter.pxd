from khash cimport *
cimport numpy as np


cdef class HashTable:
    pass


cdef class Int64HashTable(HashTable):
    cdef kh_int64_t *table
    cdef inline Py_ssize_t get_item(self, int64_t key)
    cdef inline set_item(self, int64_t key, Py_ssize_t val)
    cpdef size(self)


cdef class ByteArrayCounter(Int64HashTable):
    cdef inline feed(self, unsigned char[:] data)
    cdef inline increase(self, int64_t key, Py_ssize_t val)
    cdef inline most_common(self, Py_ssize_t size=*)
