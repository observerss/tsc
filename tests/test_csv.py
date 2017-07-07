import tsc
from tsc import compress, decompress


def test_int(): 
    raw = 'a,b\n1,2'
    m = compress(raw) 
    assert decompress(m) == b'a,b\n1,2\n'

    raw = 'a,b\n1,2\n'
    m = compress(raw) 
    assert decompress(m) == b'a,b\n1,2\n'


def test_float():
    raw = 'a,b\n1.2,2'
    m = compress(raw) 
    assert decompress(m) == b'a,b\n1.2,2\n'

    raw = 'a,b\n1.2,2.333'
    m = compress(raw) 
    assert decompress(m) == b'a,b\n1.2,2.333\n'

    raw = 'a,b\n1.2,2.333'
    m = compress(raw, precision=2) 
    assert decompress(m) == b'a,b\n1.2,2.33\n'

    raw = 'a,b\n1,2\n1.1,2\n'
    m = compress(raw)
    assert decompress(m) == b'a,b\n1.0,2\n1.1,2\n'


def test_format():
    raw = 'a,b\n1,2'
    m = compress(raw)
    a = decompress(m, format='np')
    assert a.a[0] == 1
    assert a.b[0] == 2

    raw = 'a,b\n3.1,4.1'
    m = compress(raw)
    a = decompress(m, format='py')
    assert a[0]['a'] == 3.1
    assert a[0]['b'] == 4.1
