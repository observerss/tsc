#!/usr/bin/env python
import sys
from setuptools import setup
from setuptools.command.install import install
from setuptools import find_packages

setup(name='tsc',
      version='0.1.2',
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
        'Programming Language :: Python',
        'Programming Language :: Python :: 3',
      ]
     )
