#!/usr/bin/env python
from setuptools import setup, find_packages

setup(name='tsc',
      version='0.1',
      description='TimeSeries Compressor',
      author='Jingchao Hu',
      author_email='jingchaohu@gmail.com',
      url='http://github.com/observerss/tsc',
      packages=find_packages(),
      package_data={'tsc': ['*.pxd', '*.pyx', 'klib/*.h']},
      include_package_data=True,
      install_requires=['numpy', 'cython', 'brotli', 'pandas'],
      classifiers=[
        'License :: OSI Approved :: BSD License',
        'Programming Language :: Python :: 3',
      ]
     )
