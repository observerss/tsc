import pyximport
import numpy as np
from os.path import join, dirname, abspath

klib_dir = abspath(join(dirname(__file__), 'klib'))
pyximport.install(setup_args={'include_dirs': [klib_dir, np.get_include()]})
